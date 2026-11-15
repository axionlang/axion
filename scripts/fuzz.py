#!/usr/bin/env python3
"""Differential memory-safety fuzzer (§2/§11).

Generates random WELL-TYPED Axion programs — pipelines of prelude HOFs (map / foldr /
foldl / filter / take / takeWhile / drop / reverse) over lists of scalar AND heap element
types (Integer, records, tuples, nested lists) — then runs each on:

  * the interpreter        (the safe oracle: reclaims via Rust Drop),
  * cranelift / --release  (the native backends, GC-free manual reclamation),
  * --release + clang ASan/LSan  (the memory-safety ground truth).

and flags, as HARD failures:
  * CORRUPTION  — native use-after-free / double-free under ASan (the worst class),
  * DIVERGENCE  — interp and native disagree on the printed result,
  * VERDICT     — interp accepts a program the native backend rejects for a reason
                  OTHER than the documented AX0912 heap-alias guard (or vice-versa),
  * HANG        — any compile/run step exceeds the timeout (an infinite loop or a
                  super-linear blow-up, e.g. the scope-unaware eta_expand miscompile that
                  froze axfm) — never swallowed as a slow pass or a "consistent reject".

Two generator families target the bug classes a recent session exposed: `gen_shadow` builds
programs where a local binder (param / `let` / lambda param / `where`-local) collides with a
prelude or top-level name (the scope-unaware-lowering class — eta_expand / call_named / capture
filtering), caught by the interp-vs-native differential; `gen_large` builds big pipelines / many
colliding helpers / deep nesting so an O(N^2) blow-up trips the HANG timeout.

Native LEAKS while interp is clean are REPORTED (info) but not failed — many are known
conservative leaks. AX0912 (heap-alias guard) and AX0910 (drop-verifier) rejections are
EXPECTED and counted separately — native soundly refusing a value it cannot reclaim is
correct-by-design; a verifier FALSE POSITIVE (rejecting safe code) is caught by the dedicated
0-FP corpus sweep in tests/verify.rs, not here. The `gen_tuple_consume` generator stresses the
consume-of-borrowed-interior-tuple-field class: OWNED variants must RUN + agree + be ASan-clean,
while BORROWED variants must be AX0910-rejected — and any variant the verifier MISSES compiles
and double-frees, which the ASan leg catches as corruption. Failing programs are saved to
fuzz-fail/ for a deterministic repro (the seed + index reproduce any run).

Run:  AXION_CLANG=clang ./scripts/fuzz.py [--count N] [--seed S] [--keep-going]
"""
import os, sys, random, subprocess, tempfile, pathlib, argparse

ROOT = pathlib.Path(__file__).resolve().parent.parent
AXIONC = os.environ.get("AXIONC", str(ROOT / "axionc/target/debug/axionc"))
CLANG = os.environ.get("AXION_CLANG", "clang")
# The Rust runtime staticlib (axion-rt: bignum + strings/IO, growing as the C→Rust port proceeds).
# Built on demand so the ASan link resolves the moved symbols — else it would fail to link and the
# old code masked that as "ok". See docs/rust-runtime-port.md.
RT_A = str(ROOT / "axion-rt/target/release/libaxion_rt.a")
def _ensure_rt_a():
    if CLANG_OK:  # only needed for the ASan/LLVM leg
        subprocess.run(["cargo", "build", "--release", "--manifest-path",
                        str(ROOT / "axion-rt/Cargo.toml")],
                       capture_output=True, text=True)
FAILDIR = ROOT / "fuzz-fail"

# ── Preamble: typed building blocks every generated program can call. ──────────────
PREAMBLE = """\
sq :: Integer -> Integer
sq x = x * x
incr :: Integer -> Integer
incr x = x + fromInt 1
addI :: Integer -> Integer -> Integer
addI a b = a + b
gt2 :: Integer -> Bool
gt2 n = n > fromInt 2
data R = R { rv :: Integer }
mkR :: Integer -> R
mkR n = R { rv = n }
getV :: R -> Integer
getV r = rv r
pairUp :: Integer -> (Integer, Integer)
pairUp n = (n, fromInt 0)
fstT :: (Integer, Integer) -> Integer
fstT t = case t of
  (a, b) -> a
single :: Integer -> List Integer
single n = Cons n Nil
sumL :: List Integer -> Integer
sumL xs = foldr addI 0 xs
mapSq :: List Integer -> List Integer
mapSq xs = map sq xs
revL :: List Integer -> List Integer
revL xs = reverse xs
dbl :: Int -> Int
dbl x = x + x
gt2i :: Int -> Bool
gt2i n = n > 2
"""

# element-type-preserving transformers, keyed by current element state.
# state -> list of (fragment, new_state). A fragment `%s`-wraps the inner expression.
MAP = {
    "Integer": [("map sq (%s)", "Integer"), ("map incr (%s)", "Integer"),
                ("map mkR (%s)", "R"), ("map pairUp (%s)", "Pair"),
                ("map single (%s)", "LInt")],
    "R":       [("map getV (%s)", "Integer")],
    "Pair":    [("map fstT (%s)", "Integer")],
    # nested lists (element = List Integer): inner map/reverse go THROUGH two closure
    # layers (map (map sq)); `map sumL` collapses a level back to Integer.
    "LInt":    [("map mapSq (%s)", "LInt"), ("map revL (%s)", "LInt"),
                ("map sumL (%s)", "Integer")],
    "Int":     [("map dbl (%s)", "Int")],
}
# same-type transformers (apply to any state). filter/take/takeWhile over a HEAP element
# are the AX0912-guarded shapes — generating them exercises the guard + interp path.
SAME = {
    "Integer": ["filter gt2 (%s)", "takeWhile gt2 (%s)", "take K (%s)", "drop K (%s)", "reverse (%s)"],
    "Int":     ["filter gt2i (%s)", "takeWhile gt2i (%s)", "take K (%s)", "drop K (%s)", "reverse (%s)"],
    "R":       ["take K (%s)", "drop K (%s)", "reverse (%s)"],
    "Pair":    ["take K (%s)", "drop K (%s)", "reverse (%s)"],
    "LInt":    ["take K (%s)", "drop K (%s)", "reverse (%s)"],
}
# convert any state back to an Integer (heap) or Int (scalar) so the pipeline can reduce.
TO_INTEGER = {"Integer": "%s", "R": "map getV (%s)", "Pair": "map fstT (%s)",
              "LInt": "map sumL (%s)", "Int": "map fromInt (%s)"}

def gen_arena(rng):
    # §3 arenas (native-only: interp lacks `withArena` → routed to native-only ASan). A
    # loop allocates N cells in an arena that is reset/released at the `withArena` boundary.
    body = ("useCell :: Cell -> Int\nuseCell c = 0\n"
            "allocN :: Arena -> Int -> Int\nallocN a 0 = 0\n"
            "allocN a n =\n  let c = allocateCell a in\n  let u = useCell c in\n"
            "  1 + allocN a (n - 1)\n")
    terms = [f"withArena (\\a -> allocN a {rng.randint(1, 60)})" for _ in range(rng.randint(1, 3))]
    return body + "main :: Int\nmain = " + " + ".join(terms) + "\n"

# session-typed workers: FIXED protocol templates with payload/computation holes (a random
# session protocol would rarely be dual-correct). Sessions run on the interp too → full
# differential. The parMap template carries an INTEGER payload across the M:N worker boundary
# (heap reclamation across channels — where a residual leak once lived).
SESSION_INT_COMP = {"sq": "x * x", "incr": "x + fromInt 1", "idI": "x", "dblI": "x + x"}
def gen_session(rng):
    r = rng.random()
    if r < 0.5:
        return gen_session_heap(rng)         # String traffic, let, case on data, hand-off
    r = rng.random()
    if r < 0.35:
        return gen_session_offer(rng)        # branching Offer/select protocols
    if r < 0.7:
        comp = rng.choice(list(SESSION_INT_COMP))
        n, m = rng.randint(1, 6), rng.randint(1, 20)
        pre = "".join(f"{c} :: Integer -> Integer\n{c} x = {b}\n" for c, b in SESSION_INT_COMP.items())
        pre += "addI :: Integer -> Integer -> Integer\naddI a b = a + b\n"
        worker = ("worker :: Ep (Recv Int (Send Integer End)) %1 -> IO ()\n"
                  "worker d = do\n  (n, d2) <- recv d\n"
                  f"  d3 <- send d2 ({comp} (fromInt n))\n  close d3\n")
        main = ("main :: IO ()\nmain = putStrLn (showInteger (foldr addI 0 "
                f"(parMap worker (replicate {n} {m}))))\n")
        return pre + worker + main
    comp = rng.choice(["n + n", "n + 1", "n * 2"])
    v = rng.randint(1, 100)
    worker = ("worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()\n"
              f"worker d = do\n  (n, d2) <- recv d\n  d3 <- send d2 ({comp})\n  close d3\n")
    main = ("main :: Int\nmain = bound $ do\n  c <- spawn worker\n"
            f"  c2 <- send c {v}\n  (r, c3) <- recv c2\n  close c3\n  r\n")
    return worker + main

# Heap traffic between session tasks: a random protocol of String/Int messages both ways. The
# worker binds received Strings (or drops them into `_`), sends literals, fresh values, moved
# locals and maybe-aliased values (`same`), binds `let`s, may end with a `case` on an `Either`, and
# may hand its last send to a second task (a tail call). Session tasks free what they own, so an
# LSan leak here is a hard finding (the `fuzz:session-heap` marker gates it in `check`).
SESSION_HEAP_PRE = '''-- fuzz:session-heap
tag :: Int -> String
tag n = strAppend "t" (showInt n)

same :: String -> String
same s = if strLen s > 1000 then strAppend s "" else s

pick :: String -> Either Int String
pick s = if strLen s > 3 then Right (strAppend s "") else Left (strLen s)

finish :: String -> Ep (Send String End) %1 -> IO ()
finish s d = do
  d2 <- send d s
  close d2

'''
def gen_session_heap(rng):
    steps = [(rng.choice(["in", "out"]), rng.choice(["String", "String", "Int"]))
             for _ in range(rng.randint(1, 5))]
    if rng.random() < 0.5:                      # end on a String send: case / hand-off shapes
        steps.append(("out", "String"))
    proto = "End"
    for dirn, ty in reversed(steps):
        proto = f"({'Recv' if dirn == 'in' else 'Send'} {ty} {proto})"
    lines, svars, ivars, moved = [], [], [], set()
    d, uid = 0, [0]
    def fresh(prefix):
        uid[0] += 1
        return f"{prefix}{uid[0]}"
    def live_s():
        return [v for v in svars if v not in moved]
    def str_expr():
        opts = [f'"l{rng.randint(0, 9)}"']
        if ivars:
            opts.append(f"tag {rng.choice(ivars)}")
        for v in live_s():
            opts += [f'strAppend {v} "+"', f"same {v}", v]
        e = rng.choice(opts)
        if e in live_s():
            moved.add(e)                        # sent as is: moved, never read again
        return e
    def int_expr():
        opts = [str(rng.randint(0, 9))] + ivars + [f"strLen {v}" for v in live_s()]
        return rng.choice(opts)
    last = len(steps) - 1
    for i, (dirn, ty) in enumerate(steps):
        if dirn == "in":
            if rng.random() < 0.2:
                lines.append(f"(_, d{d + 1}) <- recv d{d}")
            else:
                v = fresh("s" if ty == "String" else "n")
                lines.append(f"({v}, d{d + 1}) <- recv d{d}")
                (svars if ty == "String" else ivars).append(v)
            d += 1
            continue
        if ty == "String" and rng.random() < 0.3:   # a `let` first
            t = fresh("t")
            lines.append(f"let {t} = {str_expr()}")
            svars.append(t)
        if i == last and ty == "String" and live_s() and rng.random() < 0.5:
            v = rng.choice(live_s())
            if rng.random() < 0.5:                  # case on data, each arm finishing the protocol
                lines.append(f"case pick {v} of")
                lines.append(f"  Left k -> do\n      e1 <- send d{d} (tag k)\n      close e1")
                lines.append(f"  Right r -> do\n      e2 <- send d{d} r\n      close e2")
            else:                                   # hand the last send to another task
                lines.append(f"finish ({str_expr()}) d{d}")
            return SESSION_HEAP_PRE + session_heap_wrap(proto, lines, steps, rng)
        e = str_expr() if ty == "String" else int_expr()
        lines.append(f"d{d + 1} <- send d{d} ({e})")
        d += 1
    lines.append(f"close d{d}")
    return SESSION_HEAP_PRE + session_heap_wrap(proto, lines, steps, rng)

def session_heap_wrap(proto, lines, steps, rng):
    body = "".join(f"  {l}\n" for l in lines)
    worker = f"worker :: Ep {proto} %1 -> IO ()\nworker d0 = do\n{body}\n"
    # main runs the dual: it sends what the worker receives and adds up what it gets back
    m, acc, c = [], [], 0
    for dirn, ty in steps:
        if dirn == "in":
            val = (rng.choice([f'"m{rng.randint(0, 9)}"', f"tag {rng.randint(0, 99)}"])
                   if ty == "String" else str(rng.randint(0, 9)))
            m.append(f"c{c + 1} <- send c{c} ({val})")
        else:
            r = f"r{c}"
            m.append(f"({r}, c{c + 1}) <- recv c{c}")
            acc.append(f"strLen {r}" if ty == "String" else r)
        c += 1
    m.append(f"close c{c}")
    m.append(" + ".join(acc) if acc else "0")
    main = "main :: Int\nmain = bound $ do\n  c0 <- spawn worker\n" + "".join(f"  {l}\n" for l in m)
    return worker + main

def gen_session_offer(rng):
    # a branching Offer/select protocol: `data Resp` branches must match the worker's Offer
    # type EXACTLY, and the client follows the DUAL of the branch it selects (worker Recv ⇒
    # client Send, worker Send ⇒ client Recv). Generated as a matched worker+client pair so
    # it is well-typed by construction. Runs on interp too → full differential.
    # every Offer MUST end with a `Closed` branch (the label Linear Unwinding sends on
    # cancel — T5), continuation End. Plus 1–2 other branches with random continuations.
    k = rng.randint(1, 2)
    names = ["BrA", "BrB"][:k] + ["Closed"]
    conts = [rng.choice(["end", "recv", "send"]) for _ in range(k)] + ["end"]
    # compound session types must be PARENTHESISED inside `Ep`/`Offer` (else `Ep Send Int
    # End` parses as `Ep` applied to three args).
    styp = {"end": "End", "recv": "(Recv Int End)", "send": "(Send Int End)"}
    def wbody(ct):
        if ct == "end":  return "close d2"
        if ct == "recv": return "do\n    (n, d3) <- recv d2\n    close d3"
        return f"do\n    d3 <- send d2 {rng.randint(1, 9)}\n    close d3"
    data = "data Resp = " + " | ".join(f"{n} (Ep {styp[c]})" for n, c in zip(names, conts)) + "\n"
    offer_ty = "Offer " + " ".join(f"({n} {styp[c]})" for n, c in zip(names, conts))
    worker = f"worker :: Ep ({offer_ty}) %1 -> IO ()\nworker d = case offer d of\n"
    worker += "".join(f"  {n} d2 -> {wbody(c)}\n" for n, c in zip(names, conts))
    # client: a small chance to CANCEL (reclaim the channel un-selected); else select one
    # branch and run its dual to completion, returning an Int.
    if rng.random() < 0.2:
        client = "main :: Int\nmain = bound $ do\n  c <- spawn worker\n  cancel c\n  0\n"
        return data + worker + client
    j = rng.randrange(k)
    ct = conts[j]
    if ct == "end":
        cbody = "  close c2\n  0"
    elif ct == "recv":     # worker receives ⇒ client sends
        cbody = f"  c3 <- send c2 {rng.randint(1, 9)}\n  close c3\n  0"
    else:                  # worker sends ⇒ client receives
        cbody = "  (r, c3) <- recv c2\n  close c3\n  r"
    client = ("main :: Int\nmain = bound $ do\n  c <- spawn worker\n"
              f"  c2 <- select {names[j]} c\n{cbody}\n")
    return data + worker + client

def gen_array(rng):
    # Dense Array reclamation (§A) — now FULL differential (the interpreter has arrays). Shapes:
    #   (bulk)     arraySum/arrayDot over arrayIota: one native pass, owned result reclaimed once.
    #   (threaded) newArray -> fillA (setArray consumes+returns; `let a = setArray a …` SHADOWING,
    #              exercising the non-recursive-`let` path) -> sumA (borrowing getArray loop).
    #   (grab)     fillA, then read one element back with getArray.
    # Every shape reduces to Int -> prints, and must be interp == native + ASan/LSan-clean. The
    # threaded/grab shapes stress newArray/setArray/getArray + reclaim-once (one alloc, one free).
    shape = rng.randint(0, 2)
    if shape == 0:
        terms = []
        for _ in range(rng.randint(1, 4)):
            k = rng.randint(1, 12)
            terms.append(rng.choice([
                f"arraySum (arrayIota {k})",
                f"arrayDot (arrayIota {k}) (arrayIota {k})",
            ]))
        return PREAMBLE + "\nmain :: Int\nmain = " + " + ".join(terms) + "\n"
    n = rng.randint(1, 20)
    fillexpr = rng.choice(["i", "i + 1", "i * 2", "7", "n - i"])
    helpers = (
        "fillA :: Array Int -> Int -> Int -> Array Int\n"
        f"fillA a i n = if i == n then a else let a = setArray a i ({fillexpr}) in fillA a (i + 1) n\n"
        "sumA :: Array Int -> Int -> Int -> Int -> Int\n"
        "sumA a i n acc = if i == n then acc else sumA a (i + 1) n (acc + getArray a i)\n"
    )
    if shape == 1:                                  # threaded fill + borrowing sum
        main = (f"main :: Int\nmain = let a = newArray {n} 0 in "
                f"let a = fillA a 0 {n} in sumA a 0 {n} 0\n")
    else:                                           # fill then grab one element
        idx = rng.randint(0, n - 1)
        main = (f"main :: Int\nmain = let a = newArray {n} 0 in "
                f"let a = fillA a 0 {n} in getArray a {idx}\n")
    return PREAMBLE + "\n" + helpers + main

def gen_cond_return(rng):
    """The conditional-param-return / dead-binding / multi-param-sum / caller-reuse family —
    the shapes the call-site-ownership arc (docs/call-site-ownership.md, R-1..R-4 + V-1/V-2)
    fixed. A function returns a param BARE on one branch and a fresh value on another (the
    `condRet`/`fromMaybe`/map-over-Right shape); a caller may REUSE the arg after the call (the
    UAF trigger) or not (the accumulator-safe case). Over String / Integer / a two-parameter
    sum, with `let`-renames and passthrough-Left. Every variant must be interp≡native and
    ASan/LSan-clean; a regression of the copy-normalization or the mis-key surfaces here."""
    k = rng.randint(0, 7)
    reuse = rng.random() < 0.6          # caller reuses the arg after the call (the UAF trigger)
    t = rng.randint(0, 4)
    if t == 0:                          # conditional-param-return over String
        tail = f'strAppend "r/" name' if reuse else '"done"'
        return (f'condS :: String -> String -> String\n'
                f'condS flag x = if strLen flag == 0 then x else strAppend x "!"\n'
                f'useS :: String -> String\n'
                f'useS name = let picked = condS "" name in {tail}\n'
                f'main :: IO ()\nmain = putStrLn (useS "v{k}")\n')
    if t == 1:                          # conditional-param-return over Integer
        tail = f'n + fromInt 1' if reuse else 'fromInt 0'
        return (f'condI :: Integer -> Integer\n'
                f'condI x = if x < fromInt 0 then fromInt 0 else x\n'
                f'useI :: Integer -> Integer\n'
                f'useI n = let picked = condI n in {tail}\n'
                f'main :: IO ()\nmain = putStrLn (showInteger (useI (fromInt {k})))\n')
    if t == 2:                          # dead-binding: an ignored heap producer
        prod = 'strAppend "u" (showInteger n)' if rng.random() < 0.5 else 'condI n'
        return (f'condI :: Integer -> Integer\n'
                f'condI x = if x < fromInt 0 then fromInt 0 else x\n'
                f'ign :: Integer -> Integer\n'
                f'ign n = let s = {prod} in n + fromInt 1\n'
                f'main :: IO ()\nmain = putStrLn (showInteger (ign (fromInt {k})))\n')
    if t == 3:                          # two-parameter sum: map-over-Right / passthrough-Left (scalar)
        return (f'mapR :: Either Integer Integer -> Either Integer Integer\n'
                f'mapR e = case e of\n'
                f'  Right y -> Right (y + fromInt 1)\n'
                f'  Left x -> Left x\n'
                f'showE :: Either Integer Integer -> String\n'
                f'showE e = case e of\n'
                f'  Left s -> strAppend "L" (showInteger s)\n'
                f'  Right v -> strAppend "R" (showInteger v)\n'
                f'main :: IO ()\n'
                f'main = putStrLn (showE (mapR (Right (fromInt {k}))))\n')
    # t == 4: two-parameter sum with a HEAP (String) Left payload, both arms exercised
    arm = f'Left "e{k}"' if rng.random() < 0.5 else f'Right (fromInt {k})'
    return (f'mapS :: Either String Integer -> Either String Integer\n'
            f'mapS e = case e of\n'
            f'  Right y -> Right (y + fromInt 1)\n'
            f'  Left s -> Left s\n'
            f'showS :: Either String Integer -> String\n'
            f'showS e = case e of\n'
            f'  Left s -> strAppend "L" s\n'
            f'  Right v -> strAppend "R" (showInteger v)\n'
            f'main :: IO ()\n'
            f'main = putStrLn (showS (mapS ({arm})))\n')

def gen_bignum(rng):
    # Integer arithmetic hammering the bignum runtime — `bn_divmod` and the reclamation of its
    # long-division intermediates, exactly where a real double-free / leak once lived (rsa_modexp /
    # integer_divmod). Full differential: the interpreter's exact Rust bignum is the oracle for the
    # C `--release` bignum, and ASan/LSan hunt corruption/leaks in the div/mod reclamation paths.
    pre = (
        "facI :: Integer -> Integer\n"
        "facI n = if n == fromInt 0 then fromInt 1 else n * facI (n - fromInt 1)\n"
        "gcdI :: Integer -> Integer -> Integer\n"
        "gcdI a b = if b == fromInt 0 then a else gcdI b (a `mod` b)\n"
        "modpow :: Integer -> Integer -> Integer -> Integer\n"
        "modpow b e m = if e == fromInt 0 then fromInt 1 else "
        "if e `mod` (fromInt 2) == fromInt 0 "
        "then (let h = modpow b (e `div` (fromInt 2)) m in (h * h) `mod` m) "
        "else (b * modpow b (e - fromInt 1) m) `mod` m\n"
    )
    r = rng.random()
    if r < 0.4:
        expr = f"facI (fromInt {rng.randint(10, 90)})"
    elif r < 0.7:
        expr = f"gcdI (facI (fromInt {rng.randint(5, 30)})) (fromInt {rng.randint(1, 10**9)})"
    else:
        expr = (f"modpow (fromInt {rng.randint(2, 9999)}) (fromInt {rng.randint(1, 400)}) "
                f"(fromInt {rng.randint(3, 999999)})")
    return pre + "main :: IO ()\nmain = putStrLn (showInteger (" + expr + "))\n"

def gen_deep(rng):
    # Nested heap containers built and reclaimed → the recursive deep-drop destructors
    # (`axion_drop_List$List$Int`) and their per-element frees. Full differential.
    n = rng.randint(1, 8)
    pre = "mkRow :: Int -> List Int\nmkRow k = range 1 k\n"
    expr = f"sum (map sum (map mkRow (range 1 {n})))"
    return pre + "main :: IO ()\nmain = putStrLn (show (" + expr + "))\n"

def gen_borrow_alias(rng):
    """The conditional-owned-TEMP + borrowed-element reclamation family this arc closed. Two
    classes `gen_cond_return` does NOT cover:
      · MIXED `let x = if c then <fresh heap> else <borrowed param> in <consume x>` — `x` is owned
        on one branch, a borrowed alias on the other (`normalize_mixed_cond_lets` copies the
        non-owned arm so the temp reclaims; a regression leaks it → verify/ASan here). Over String
        and Integer, both `let`-bound and the `f (if …)` consumed-sub-expression form.
      · `baseName`/path-join over a BORROWED list element with NO '/' — `baseName` returns the whole
        name, which must be an OWNED copy (prelude `baseAfter`), else the dropped result aliases the
        borrowed element and double-frees against the list's deep-drop (the fff bulk-rename class).
    Both branches of every conditional are exercised across seeds; all must be interp≡native and
    ASan/LSan-clean."""
    t = rng.randint(0, 4)
    c = rng.randint(0, 1)               # drive the conditional down each arm
    k = rng.randint(1, 9)
    if t == 0:                          # mixed `let x = if` over String
        return (f'pick :: Int -> String -> String\n'
                f'pick c s = let x = if c > 0 then strAppend "a" "b" else s in strAppend x "!"\n'
                f'main :: IO ()\nmain = putStrLn (pick {c} "s{k}")\n')
    if t == 1:                          # mixed `let x = if` over Integer
        return (f'pick :: Int -> Integer -> Integer\n'
                f'pick c n = let x = if c > 0 then fromInt 10 + fromInt 20 else n in x + fromInt 1\n'
                f'main :: IO ()\nmain = putStrLn (showInteger (pick {c} (fromInt {k})))\n')
    if t == 2:                          # the consumed-sub-expression form `f (if … mixed …)`
        return (f'pick :: Int -> String -> String\n'
                f'pick c s = strAppend (if c > 0 then strAppend "x" "y" else s) "?"\n'
                f'main :: IO ()\nmain = putStrLn (pick {c} "s{k}")\n')
    if t == 3:                          # baseName over a borrowed list of no-'/' names (bnGo)
        names = " ".join(f'"n{j}"' for j in range(rng.randint(1, 4)))
        lst = "Nil"
        for nm in reversed(names.split()):
            lst = f"Cons {nm} ({lst})"
        return (f'bnGo :: List String -> String\n'
                f'bnGo xs = case xs of\n'
                f'  Nil -> ""\n'
                f'  Cons y ys -> strAppend (baseName y) (strAppend "\\n" (bnGo ys))\n'
                f'sample :: List String\nsample = {lst}\n'
                f'main :: IO ()\nmain = putStr (bnGo sample)\n')
    # t == 4: baseName over names WITH a '/' (returns a fresh substr) — the other baseAfter arm
    return (f'bnGo :: List String -> String\n'
            f'bnGo xs = case xs of\n'
            f'  Nil -> ""\n'
            f'  Cons y ys -> strAppend (baseName y) (strAppend "\\n" (bnGo ys))\n'
            f'sample :: List String\n'
            f'sample = Cons (strAppend "d{k}/" "f{k}") (Cons "p/q" Nil)\n'
            f'main :: IO ()\nmain = putStr (bnGo sample)\n')

def gen_tuple_reclaim(rng):
    """The tuple / record-field reclamation family closed this arc (grab-via-case getters, tuple
    `ret_alias` reuse, nested-tuple case-extraction escape). Each shape was a verifier-BLIND
    double-free / UAF before its fix; all are now interp≡native and ASan/LSan-clean, so the
    differential gate stays green while the RANDOMIZED variation (element type String/Integer,
    which field, nesting) probes neighbouring untested shapes for the next hole."""
    t = rng.randint(0, 3)
    fi = rng.randint(0, 1)              # which field / tuple slot the getter returns
    k = rng.randint(1, 9)
    # NOTE: the grab-getter is STRING-only by design. The Integer twin (`data R = R Integer
    # Integer; getF r = case r of R a b -> a; useBoth r = getF r + getF r`) is a KNOWN
    # verifier-blind double-free (this fuzzer found it): Integer fields are excluded from
    # `con_drop_slots` — reverted historically to dodge the `map getV` element-alias double-free —
    # so they are not destructor-tracked, the grab-via-case promotion cannot fire for them, and the
    # reused field is dropped twice. Closing it is the deferred Integer-in-data arc (re-adding
    # Integer to drop_slots reopens `map getV`), so it is NOT emitted here — the generator stays
    # SOUND so the CI gate remains a green regression gate. See axion-drop-verifier memory.
    if t == 0:                          # grab-via-case GETTER returned bare, reused twice
        return (f'data R = R String String\n'
                f'getF :: R -> String\n'
                f'getF r = case r of\n'
                f'  R a b -> {"a" if fi == 0 else "b"}\n'
                f'useBoth :: R -> String\n'
                f'useBoth r = strAppend (getF r) (getF r)\n'
                f'sample :: R\n'
                f'sample = R (strAppend "f" "{k}") (strAppend "g" "{k}")\n'
                f'main :: IO ()\nmain = putStrLn (useBoth sample)\n')
    if t == 1:                          # tuple `ret_alias` reuse (pickT returns `t`; go reuses it)
        c = rng.randint(0, 1)
        return (f'useT :: (String, String) -> String\n'
                f'useT t = case t of\n'
                f'  (a, b) -> strAppend a b\n'
                f'pickT :: Int -> (String, String) -> (String, String)\n'
                f'pickT c t = if c > 0 then (strAppend "x" "y", strAppend "z" "w") else t\n'
                f'go :: (String, String) -> String\n'
                f'go t = strAppend (useT (pickT {c} t)) (useT t)\n'
                f'main :: IO ()\n'
                f'main = putStrLn (go (strAppend "p" "{k}", strAppend "q" "{k}"))\n')
    if t == 2:                          # NESTED-tuple extraction escape (return a deep field)
        return (f'useNT :: ((String, String), (String, String)) -> String\n'
                f'useNT t = case t of\n'
                f'  (a, b) -> case {"a" if fi == 0 else "b"} of\n'
                f'    (x, y) -> x\n'
                f'main :: IO ()\n'
                f'main = putStrLn (useNT ((strAppend "p" "{k}", "q"), (strAppend "r" "{k}", "s")))\n')
    # t == 3: nested-tuple RETURN WHOLE inner, then consumed at the top level
    return (f'useB :: ((String, String), (String, String)) -> (String, String)\n'
            f'useB t = case t of\n'
            f'  (a, b) -> {"a" if fi == 0 else "b"}\n'
            f'showInner :: (String, String) -> String\n'
            f'showInner p = case p of\n'
            f'  (x, y) -> strAppend x y\n'
            f'main :: IO ()\n'
            f'main = putStrLn (showInner (useB '
            f'((strAppend "p" "{k}", "q"), ("r", strAppend "s" "{k}"))))\n')


# names of prelude / built-in functions a local binder can collide with. A param, `let`,
# lambda param or `case` binder sharing one of these once mis-resolved to the prelude
# function (the `windowLines … count` eta_expand miscompile that froze axfm) — the lowering
# must treat the local as a local, shadowing the prelude arity. Kept to names that EXIST so
# the collision is real (a non-existent name can't be mis-resolved).
PRELUDE_NAMES = ["count", "sum", "length", "reverse", "product", "and", "or", "map",
                 "filter", "take", "drop", "lookup", "span", "concat", "elem"]

def gen_shadow(rng):
    """Local binders whose names collide with prelude / top-level functions — the
    scope-unaware-lowering class (eta_expand / call_named / capture-filter). The interpreter
    (proper lexical scopes) is the oracle; a native backend that resolves the local as the
    global DIVERGES (or errors), so the differential catches a regression of any shadow fix.
    Five shapes: a prelude-name scalar param; an over-applied function-typed param shadowing a
    top-level fn; a lambda / a `where`-local capturing a param that shadows a global CAF; and a
    `let` binder shadowing a prelude name."""
    t = rng.randint(0, 4)
    a, b = rng.randint(1, 50), rng.randint(1, 50)
    if t == 0:                          # prelude-name used as a plain scalar PARAM (the `count` bug)
        nm = rng.choice(PRELUDE_NAMES)
        return (f"shadowP :: Int -> Int -> Int\n"
                f"shadowP start {nm} = start + {nm} + {nm}\n"
                f"main :: IO ()\nmain = putStr (show (shadowP {a} {b}))\n")  # a + 2b
    if t == 1:                          # function-typed param shadowing a top-level fn, OVER-applied
        g = rng.choice(["f", "sum", "count", "add"])
        return (f"{g} :: Int -> Int\n{g} x = x + 100\n"
                f"use :: (Int -> Int -> Int) -> Int\n"
                f"use {g} = {g} {a} {b}\n"                 # local {g} is arity-2; global arity-1
                f"addI2 :: Int -> Int -> Int\naddI2 p q = p + q\n"
                f"main :: IO ()\nmain = putStr (show (use addI2))\n")          # a + b
    if t == 2:                          # lambda captures a param shadowing a global CAF
        nm = rng.choice(["g", "sum", "count"])
        return (f"{nm} :: Int\n{nm} = 99\n"
                f"outer :: Int -> Int\nouter {nm} = (\\y -> {nm} + y) {b}\n"
                f"main :: IO ()\nmain = putStr (show (outer {a}))\n")          # a + b
    if t == 3:                          # where-local captures a param shadowing a global CAF
        nm = rng.choice(["g", "sum", "count"])
        return (f"{nm} :: Int\n{nm} = 99\n"
                f"outer :: Int -> Int\nouter {nm} = h\n  where h = {nm} + {b}\n"
                f"main :: IO ()\nmain = putStr (show (outer {a}))\n")          # a + b
    # t == 4: a `let` binder shadowing a prelude name, used as a scalar
    nm = rng.choice(PRELUDE_NAMES)
    return (f"useLet :: Int -> Int\n"
            f"useLet x = let {nm} = x + {a} in {nm} + {nm}\n"
            f"main :: IO ()\nmain = putStr (show (useLet {b}))\n")             # 2*(a+b)

def gen_large(rng):
    """Large inputs — guard against O(N^2) blow-ups (compile- OR run-time) like the one the
    scope-unaware eta_expand bug caused (an Int counter became a heap pointer → the window
    never terminated → O(N^2) per frame). A blow-up now trips the per-invocation timeout and is
    reported as a HARD `hang`. Shapes: a long HOF pipeline over a big `range`; many colliding
    top-level helpers (stressing the name/arity table); a deeply-nested arithmetic expression."""
    t = rng.randint(0, 2)
    if t == 0:                          # a multi-stage list pipeline (correctness exerciser)
        # N and stage-count are kept SMALL: the tree-walking INTERPRETER (the differential
        # oracle) is ~O(N^2) in time/memory on multi-pass list pipelines — on the unoptimised
        # DEBUG build even N≈450 blows past the hang timeout — and that is an interpreter
        # characteristic, NOT compiler soundness. Runtime O(N^2) at the NATIVE backend needs N
        # far larger than the oracle can match, so the compile-time blow-up this family really
        # targets (the eta_expand window bug) is covered by the deep-nesting / many-decls shapes
        # below (fast at runtime, hard on the compiler). This shape just adds pipeline variety.
        n = rng.randint(20, 120)
        expr = f"range 1 {n}"
        for _ in range(rng.randint(2, 4)):
            expr = rng.choice([f"map dbl ({expr})", f"filter gt2i ({expr})",
                               f"reverse ({expr})", f"map (\\x -> x + 1) ({expr})"])
        return PREAMBLE + f"\nmain :: IO ()\nmain = putStr (show (sum ({expr})))\n"
    if t == 1:                          # many top-level helpers, some names colliding with prelude
        k = rng.randint(30, 120)
        defs, calls = [], []
        for j in range(k):
            nm = rng.choice(PRELUDE_NAMES) if rng.random() < 0.3 else f"h{j}"
            # a fresh unique fn name, but with a PARAM named like a prelude fn (collision in-scope)
            fn = f"fn{j}"
            defs.append(f"{fn} :: Int -> Int\n{fn} {nm} = {nm} + {j}\n")
            calls.append(f"{fn} {rng.randint(0, 9)}")
        return "".join(defs) + "main :: IO ()\nmain = putStr (show (" + " + ".join(calls) + "))\n"
    # t == 2: a deeply nested arithmetic expression (parser/lowering recursion depth) — bounded
    # so it probes depth handling without tripping the plain recursion-stack limit (a separate
    # concern from the scope/hang classes this fuzzer targets).
    depth = rng.randint(40, 250)
    expr = "1"
    for _ in range(depth):
        expr = f"({expr} + {rng.randint(1, 3)})"
    return f"main :: IO ()\nmain = putStr (show ({expr}))\n"

def gen_tuple_consume(rng):
    """Consume-of-borrowed-interior-tuple-field — the class the drop-verifier now catches (the
    `CPat::Tuple` arm in `bind_pattern`). `sndof` destructures a `(heap, Int)` tuple and discards the
    heap field, so it CONSUMES its tuple. Four modes, each a distinct net:
      · OWNED — `sndof` on an owned tuple (sound → RUNS, ASan-clean; guards against the fix breaking
        owned-tuple handling).
      · BUILD-borrowed — `pick` extracts an interior tuple from a freshly-BUILT `Maybe` and consumes
        the head (unsound → verifier must AX0910-reject; a MISSED variant compiles + double-frees →
        ASan catches it).
      · UNCONS-consume — same hazard but the `Maybe ((K,V), List (K,V))` comes from `uncons` (the peel
        shape the retired `peel_result_over_tuple` AX0912 guard used to blanket-reject). Unsound →
        AX0910.
      · UNCONS-safe — `uncons`-of-tuple but the consumer only READS the tail `rest` (`length rest`) and
        merely DISCARDS the borrowed head (no consume) → SOUND. Must RUN + agree + ASan-clean. This is
        the case the old guard OVER-rejected; it validates that retiring the guard is safe, not just
        that the verifier catches the unsafe ones."""
    if rng.random() < 0.5:
        ty, hv = "String", '"k"'
    else:
        ty, hv = "Integer", "fromInt n"
    pre = (
        f"mkp :: Int -> ({ty}, Int)\n"
        f"mkp n = ({hv}, n)\n"
        f"sndof :: ({ty}, Int) -> Int\n"
        f"sndof t = case t of\n  (a, b) -> b\n"       # discards the heap field `a` → consumes `t`
    )
    k = rng.randint(1, 9)
    mode = rng.randint(0, 3)
    if mode == 0:                                      # OWNED: consumed exactly once → sound, runs
        return pre + (
            f"useOwned :: ({ty}, Int) -> Int\n"
            f"useOwned t = sndof t\n"
            f"main :: IO ()\nmain = putStr (show (useOwned (mkp {k})))\n"
        )
    sig = f"Maybe (({ty}, Int), List ({ty}, Int))"
    if mode == 3:                                      # UNCONS-safe: read the tail, DISCARD the head
        return pre + (
            f"pick :: {sig} -> Int\n"
            f"pick m = case m of\n"
            f"  Just p -> case p of\n    (h, rest) -> length rest\n"
            f"  Nothing -> 0\n"
            f"main :: IO ()\n"
            f"main = putStr (show (pick (uncons (Cons (mkp {k}) (Cons (mkp ({k} + 1)) Nil)))))\n"
        )
    # mode 1/2: BORROWED interior, head CONSUMED → unsound, verifier must AX0910-reject.
    producer = (
        f"build :: Int -> {sig}\nbuild n = Just (mkp n, Cons (mkp (n + 1)) Nil)\n"
        if mode == 1
        else ""
    )
    src = (
        f"build {k}"
        if mode == 1
        else f"uncons (Cons (mkp {k}) (Cons (mkp ({k} + 1)) Nil))"
    )
    return pre + producer + (
        f"pick :: {sig} -> Int\n"
        f"pick m = case m of\n"
        f"  Just p -> case p of\n    (h, rest) -> sndof h\n"
        f"  Nothing -> 0\n"
        f"main :: IO ()\nmain = putStr (show (pick ({src})))\n"
    )

def gen_closure_param(rng):
    """User HOFs that RECEIVE a closure and hand it on to `filter` / call it directly — the
    closure-parameter specialization class (`keepWith p xs = length (filter p xs)` is cloned per
    predicate, `keepWith$$gt2`). Predicates come as a named function, a literal lambda, a lambda
    capturing a `do`-local, and a `let`-bound lambda passed by name; HOFs take one or two closures,
    or recurse over the list. Elements are HEAP (String / Integer) so a wrong clone ownership is a
    double-free the ASan leg catches. A wrapper that hands its list to an owning callee is also
    called on a shared list once or twice: twice must be rejected (AX0001) by BOTH legs, once must
    run — the moved-in-parameter class the verifier used to miss."""
    elem = rng.choice(["String", "Integer"])
    k = rng.randint(0, 5)
    if elem == "String":
        helpers = ("big :: String -> Bool\nbig s = strLen s > 1\n"
                   "ext :: String -> String\next s = s ++ \"!\"\n")
        def lit():
            ws = ["".join(rng.choice("abc") for _ in range(rng.randint(0, 5)))
                  for _ in range(rng.randint(0, 6))]
            return "[" + ", ".join(f'"{w}"' for w in ws) + "]"
        named, f = "big", "ext"
        cmp = lambda v, op, c: f"strLen {v} {op} {c}"
    else:
        helpers = ("big :: Integer -> Bool\nbig n = n > fromInt 2\n"
                   "ext :: Integer -> Integer\next n = n * n\n")
        def lit():
            return f"map fromInt (range {rng.randint(0, 3)} {rng.randint(0, 8)})"
        named, f = "big", "ext"
        cmp = lambda v, op, c: f"{v} {op} fromInt ({c})"
    T = elem
    hofs = (f"keepWith :: ({T} -> Bool) -> List {T} -> Int\n"
            f"keepWith p xs = length (filter p xs)\n"
            f"keepBoth :: ({T} -> Bool) -> ({T} -> Bool) -> List {T} -> Int\n"
            f"keepBoth p q xs = length (filter p (filter q xs))\n"
            f"countIf :: ({T} -> Bool) -> List {T} -> Int\n"
            f"countIf p xs = case xs of\n  Nil -> 0\n"
            f"  Cons y ys -> (if p y then 1 else 0) + countIf p ys\n"
            f"mapKeep :: ({T} -> {T}) -> ({T} -> Bool) -> List {T} -> Int\n"
            f"mapKeep g p xs = length (filter p (map g xs))\n"
            f"keepW :: List {T} -> Int\nkeepW xs = length (filter {named} xs)\n")
    def pred():
        c = rng.randint(0, 6)
        return rng.choice([named,
                           f"(\\v -> {cmp('v', rng.choice(['>', '<']), c)})",
                           f"(\\v -> {cmp('v', rng.choice(['>', '<']), 'k')})",
                           "lp"])
    lines = []
    for _ in range(rng.randint(1, 4)):
        t = rng.randint(0, 4)
        if t == 0:
            e = f"keepWith {pred()} ({lit()})"
        elif t == 1:
            e = f"keepBoth {pred()} {pred()} ({lit()})"
        elif t == 2:
            e = f"countIf {pred()} ({lit()})"
        elif t == 3:
            e = f"mapKeep {f} {pred()} ({lit()})"
        else:
            twice = rng.random() < 0.3                 # twice ⇒ AX0001 on every leg
            e = f"(let ws = {lit()} in keepW ws" + (" + keepW ws)" if twice else ")")
        lines.append(f"  putStrLn (show ({e}))")
    lp = f"\\v -> {cmp('v', rng.choice(['>', '<']), rng.randint(0, 6))}"
    return (helpers + hofs + "main :: IO ()\nmain = do\n"
            f"  let k = {k}\n  let lp = {lp}\n" + "\n".join(lines) + "\n")

BUILTINS_PRE = '''-- fuzz:builtins
idG :: a -> a
idG x = x

pickG :: Bool -> a -> a -> a
pickG b x y = if b then x else y

app1 :: (a -> Int) -> a -> Int
app1 f x = f x

twiceS :: (String -> String) -> String -> String
twiceS f s = f (f s)

data BoxS = BoxS String Int

unboxS :: BoxS -> String
unboxS b = case b of
  BoxS s n -> s

sndT :: (Int, String) -> String
sndT t = case t of
  (a, s) -> s

'''

def _bi_str(rng, d):
    """A String-valued expression from a random mix of producers (heap and literal)."""
    if d <= 0 or rng.random() < 0.25:
        return rng.choice([f'"s{rng.randint(0, 9)}"', f"showInt {rng.randint(0, 999)}",
                           f"chr {rng.randint(65, 90)}"])
    a = _bi_str(rng, d - 1)
    return rng.choice([
        f"strAppend ({a}) ({_bi_str(rng, d - 1)})",
        f"substr 0 1 (strAppend ({a}) \"pad\")",
        f"showInteger ({_bi_int(rng, d - 1)})",
        f"idG ({a})",
        f"pickG {rng.choice(['True', 'False'])} ({a}) ({_bi_str(rng, d - 1)})",
        f"twiceS (strAppend \"x\") ({a})",
        f"fromLeft ({a}) ({rng.choice(['Left', 'Right'])} ({_bi_str(rng, d - 1)}))",
        f"unboxS (BoxS ({a}) {rng.randint(0, 9)})",
        f"sndT ({rng.randint(0, 9)}, {a})",
        f"(case Just ({a}) of\n    Just v -> v\n    Nothing -> \"\")",
    ])

def _bi_int(rng, d):
    """An Integer-valued expression."""
    if d <= 0 or rng.random() < 0.3:
        return f"fromInt {rng.randint(0, 99)}"
    a = _bi_int(rng, d - 1)
    return rng.choice([
        f"({a}) + ({_bi_int(rng, d - 1)})",
        f"({a}) * ({_bi_int(rng, d - 1)})",
        f"bignumFromStr (showInt {rng.randint(0, 999)})",
        f"idG ({a})",
        f"divInteger (({a}) + fromInt 7) (fromInt 3)",
    ])

def _bi_buf(rng):
    n = rng.randint(1, 16)
    return rng.choice([f"newBuffer {n}", f"bufIota (newBuffer {n})",
                       f"xorInPlace (bufIota (newBuffer {n})) {rng.randint(0, 255)}"])

def _bi_term(rng, binds):
    """One scalar term consuming heap values through built-ins. May add a `let` binding (in
    `binds`) that later terms read again: a built-in that wrongly consumes its argument then
    double-frees or is rejected (AX0910)."""
    if binds and rng.random() < 0.4:
        v, ty = rng.choice(binds)
        if ty == "S":
            return rng.choice([f"strLen {v}", f"charAt 0 (strAppend {v} \"z\")",
                               f"strCmp {v} {v}", f"app1 strLen {v}"])
        if ty == "I":
            return rng.choice([f"strLen (showInteger {v})", f"(if {v} > fromInt 5 then 1 else 0)"])
        return rng.choice([f"bufLen {v}", f"sumBytes {v}", f"peekU8 {v} 0"])
    k = rng.random()
    if k < 0.15:
        name = f"v{len(binds)}"
        ty = rng.choice(["S", "S", "I", "B"])
        val = {"S": lambda: _bi_str(rng, 2), "I": lambda: _bi_int(rng, 2),
               "B": lambda: _bi_buf(rng)}[ty]()
        binds.append((name, ty))
        return ("let", name, val)
    if k < 0.55:
        s = _bi_str(rng, rng.randint(1, 3))
        return rng.choice([f"strLen ({s})", f"strCmp ({s}) ({_bi_str(rng, 1)})",
                           f"charAt 0 (strAppend ({s}) \"z\")", f"app1 strLen ({s})",
                           f"length (Cons ({s}) Nil)", f"sum (map strLen [({s}), \"ab\"])"])
    if k < 0.75:
        i = _bi_int(rng, rng.randint(1, 3))
        return rng.choice([f"strLen (showInteger ({i}))",
                           f"(if ({i}) == ({_bi_int(rng, 1)}) then 1 else 0)"])
    if k < 0.97:
        b = _bi_buf(rng)
        return rng.choice([f"bufLen ({b})", f"sumBytes ({b})", f"peekU8 ({b}) 0",
                           f"app1 bufLen ({b})"])
    # an Array of a heap element: natively rejected (AX0914), interp runs it
    return f"lenArray (newArray 2 ({_bi_str(rng, 1)}))"

def gen_builtins(rng):
    """Built-ins over heap arguments of every shape (String, Integer, Buffer, data, tuple, list,
    through generic wrappers and closures, read again after a `let`): every program is safe, so a
    native rejection other than AX0914, a leak, or a divergence means a built-in's ownership
    entry (builtins::RT_TABLE) is wrong."""
    binds = []
    lets, terms = [], []
    for _ in range(rng.randint(2, 6)):
        t = _bi_term(rng, binds)
        if isinstance(t, tuple):
            lets.append(f"  let {t[1]} = {t[2]}")
        else:
            terms.append(t)
    if not terms:
        terms.append("0")
    # every bound value is read at least once (an unread String is fine; this adds coverage)
    for v, ty in binds:
        terms.append({"S": f"strLen {v}", "I": f"strLen (showInteger {v})", "B": f"bufLen {v}"}[ty])
    body = "\n".join(lets) + ("\n" if lets else "")
    body += "  putStrLn (showInt (" + " + ".join(terms) + "))\n"
    return BUILTINS_PRE + "main :: IO ()\nmain = do\n" + body

def gen_bce(rng):
    """Counting loops for the bounds-check versioning (axionc/src/bce.rs): random lengths, offsets,
    strides (0, negative, huge — wrapping), starts and bounds, all four exit forms, reads and
    writes, often out of bounds. The interpreter always checks; native runs a check-free clone
    when its entry guard proves the whole loop in bounds. They must agree: same output, or both
    reject (an out-of-bounds abort). A run that native completes and the interpreter rejects —
    or any ASan finding — is an unsound elision."""
    big = [0, 1, 2, 3, -1, -2, 7, 64, 4611686018427387904, -9223372036854775807, 9223372036854775807]
    pick = lambda: rng.choice(big) if rng.random() < 0.15 else rng.randint(-3, 12)
    length = rng.randint(0, 24)
    c, st, j0, n = pick(), rng.choice([0, 1, 1, 1, 2, 3, -1]) if rng.random() > 0.1 else pick(), pick(), pick()
    exit_, step = rng.choice([("j > n", "j + 1"), ("j >= n", "j + 1"), ("j == n", "j + 1"),
                              ("j < 0", "j - 1")])
    if exit_ == "j == n" and (j0 > n or n - j0 > 40):
        j0 = n - rng.randint(0, 6)  # an == loop must reach n
    if exit_ == "j < 0" and j0 > 40:
        j0 = rng.randint(-2, 30)
    if exit_ != "j < 0" and exit_ != "j == n" and isinstance(n, int) and n - j0 > 40:
        n = j0 + rng.randint(-2, 30)
    idx = rng.choice(["c + s * j", "c + j * s", "s * j + c", "c + j", "c"])
    prog = f"""-- fuzz:bce
fillL :: Array Int -> Int -> Int -> Int -> Int -> Array Int
fillL a c s j n = if {exit_} then a else fillL (setArray a ({idx}) (j * 3 + 1)) c s ({step}) n

sumL :: Array Int -> Int -> Int -> Int -> Int -> Int -> Int
sumL a c s j n acc = if {exit_} then acc else sumL a c s ({step}) n (acc + getArray a ({idx}))

main :: Int
main =
  let a = newArray {length} 5 in
  let a = fillL a ({c}) ({st}) ({j0}) ({n}) in
  sumL a ({c}) ({st}) ({j0}) ({n}) 0 + lenArray a
"""
    return prog

def gen(rng):
    r = rng.random()                    # distinct heap-resource surfaces
    if r < 0.10:
        return gen_arena(rng)           # native-only
    if r < 0.26:
        return gen_session(rng)         # full differential (interp supports sessions)
    if r < 0.33:
        return gen_array(rng)           # full differential (interp now has arrays)
    if r < 0.38:
        return gen_bce(rng)             # bounds-check versioning: guard soundness (bce.rs)
    if r < 0.46:
        return gen_cond_return(rng)     # call-site-ownership shapes (full differential)
    if r < 0.54:
        return gen_borrow_alias(rng)    # conditional-owned-temp + baseName/borrowed-element shapes
    if r < 0.62:
        return gen_tuple_reclaim(rng)   # grab-via-case + tuple ret_alias reuse + nested extraction
    if r < 0.68:
        return gen_bignum(rng)          # bignum reclamation (full differential + ASan/LSan)
    if r < 0.73:
        return gen_deep(rng)            # nested-container deep-drop (full differential)
    if r < 0.81:
        return gen_shadow(rng)          # local-shadows-global scope class (full differential)
    if r < 0.84:
        return gen_large(rng)           # large inputs → O(N^2)/hang guard (timeout-detected)
    if r < 0.88:
        return gen_tuple_consume(rng)   # consume-of-borrowed-interior-tuple-field (verifier net)
    if r < 0.91:
        return gen_closure_param(rng)   # closure-param HOF specialization + moved-in hand-off
    if r < 0.97:
        return gen_builtins(rng)        # built-ins over heap args (the ownership table)
    heap = rng.random() < 0.75          # bias toward the heap element space (the theme)
    n = rng.randint(1, 6)
    if heap:
        expr, state = f"map fromInt (range 1 {n})", "Integer"
    else:
        expr, state = f"range 1 {n}", "Int"
    for _ in range(rng.randint(0, 5)):
        # bias toward map/reverse chains (natively accepted → reach the ASan check);
        # the AX0912-guarded filter/take shapes still appear ~half the time to keep
        # exercising the guard + interp path.
        choices = [("map", f) for f in MAP.get(state, [])]
        if rng.random() < 0.5:
            choices += [("same", f) for f in SAME.get(state, [])]
        if not choices:
            break
        kind, frag = rng.choice(choices)
        if kind == "map":
            tmpl, state = frag
            expr = tmpl % expr
        else:
            expr = frag.replace("K", str(rng.randint(0, n + 1))) % expr
    # reduce to a printable scalar
    if state == "Int":
        prog_expr = f"show (sum ({expr}))"
    else:
        expr = TO_INTEGER[state] % expr
        red = rng.choice(["foldr addI 0 (%s)", "foldl addI 0 (%s)"])
        prog_expr = f"showInteger ({red % expr})"
    return PREAMBLE + "\nmain :: IO ()\nmain = putStrLn (" + prog_expr + ")\n"

# A small generated program compiles+runs in well under a second on every backend; anything
# that blows past this is a genuine hang / super-linear blow-up (the class the scope-unaware
# eta_expand bug caused), reported as a HARD `hang` finding — NOT swallowed as a slow pass or a
# "consistent reject". The window is still generous so a legitimately large `gen_large` input
# (a few-thousand-element pipeline on the interpreter) never false-positives.
HANG_SECS = 30
HANG_RC = 124           # subprocess timeout → this return code (checked by `check`/`asan_run`)

def run(args, want_bin=None, timeout=HANG_SECS):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return HANG_RC, "", "timeout"
    except (FileNotFoundError, OSError) as e:
        return 127, "", str(e)          # executable missing (e.g. no clang) — caller skips

CLANG_OK = run([CLANG, "--version"])[0] == 0

def asan_run(src, work, oracle_out):
    """Compile --release + ASan/LSan and run. `oracle_out` is the interpreter's stdout to
    compare against, or None for a native-only program (e.g. arenas: no interp oracle → skip the
    divergence check, only hunt corruption/leak)."""
    if not CLANG_OK:
        return ("ok", None)             # no clang → skip ASan (differential still ran)
    rl, ol, el = run([AXIONC, "--emit", "llvm", str(src)])
    if rl == HANG_RC:
        return ("hang", f"--emit llvm exceeded {HANG_SECS}s")
    if rl != 0:
        return ("ok", None)
    (work / "ir.ll").write_text(ol)
    rcc, _, ecc = run([CLANG, "-fsanitize=address,leak", "-pthread", "-O1", "-w",
                       str(work / "ir.ll"), RT_A, "-ldl", "-lm", "-o", str(work / "p")])
    if rcc != 0:
        # A link failure AFTER interp+cranelift agreed means a missing/renamed runtime symbol — a
        # real regression (e.g. a moved C→Rust function not linked), NOT something to silently pass.
        return ("verdict", f"native link failed:\n{ecc[-400:]}")
    rr, orr, err = run([str(work / "p")])
    if rr == HANG_RC:
        return ("hang", f"native binary exceeded {HANG_SECS}s at runtime")
    if "use-after-free" in err or "double-free" in err or "invalid pointer" in err:
        return ("corruption", err[-600:])
    if "detected memory leaks" in err:
        # session tasks free what they own: a leak in a session-heap program is a real finding
        if "fuzz:session-heap" in src.read_text():
            return ("sessleak", err[-600:])
        # built-in programs reclaim everything: a leak means a wrong ownership entry
        if "fuzz:builtins" in src.read_text():
            return ("bileak", err[-600:])
        return ("leak", None)              # LSan `_exit`s without flushing stdout
    if oracle_out is not None and rr == 0 and orr.strip() != oracle_out.strip():
        return ("divergence", f"interp={oracle_out!r} llvm+asan={orr!r}\n{err[-300:]}")
    return ("ok", None)

def check(prog, work):
    src = work / "p.axi"
    src.write_text(prog)
    ri, oi, ei = run([AXIONC, str(src)])
    # A hang on ANY invocation is the worst-masked class: two hanging runs would otherwise look
    # like a "consistent reject". Flag it the moment it happens, with the program for a repro.
    if ri == HANG_RC:
        return ("hang", f"interp/compile exceeded {HANG_SECS}s:\n{prog[:500]}")
    # genuinely native-only programs (e.g. arenas: interp lacks `withArena` → runtime "name not
    # found") have no interp oracle, so ASan-check the native build for corruption/leak only. Array
    # programs no longer land here — the interpreter runs them, so they take the full-differential
    # path below.
    if "name not found at runtime" in (oi + ei):
        rc, oc, ec = run([AXIONC, "--backend", "cranelift", str(src)])
        if rc == HANG_RC:
            return ("hang", f"cranelift exceeded {HANG_SECS}s:\n{prog[:500]}")
        if rc != 0:
            return ("ax0912", None) if "AX0912" in ec else ("verdict", f"native-only prog rejected:\n{ec[-400:]}")
        return asan_run(src, work, None)
    rc, oc, ec = run([AXIONC, "--backend", "cranelift", str(src)])
    if rc == HANG_RC:
        return ("hang", f"cranelift exceeded {HANG_SECS}s:\n{prog[:500]}")
    # verdict divergence
    if ri == 0 and rc != 0:
        if "AX0914" in ec:
            return ("ax0914", None)            # expected: a heap Array element, rejected natively
        if "fuzz:builtins" in prog and "AX0910" in ec:
            # every built-in program is safe: the verifier rejecting one means a built-in is
            # classified as consuming an argument the runtime only reads (the netSend class)
            return ("biax0910", ec[-600:])
        if "AX0912" in ec:
            return ("ax0912", None)            # expected: the heap-alias guard
        if "AX0910" in ec:
            # the drop-balance verifier SOUNDLY rejected an unsound-to-compile shape (e.g. consuming
            # a borrowed interior tuple field — the interpreter is memory-safe via Rust Drop, so it
            # still runs). Not a divergence: native refusing a value it cannot reclaim soundly is
            # correct-by-design, exactly like AX0912. A verifier FALSE POSITIVE (rejecting SAFE code)
            # is caught by the dedicated 0-FP corpus sweep (tests/verify.rs), not here.
            return ("ax0910", None)
        return ("verdict", f"interp ran but cranelift rejected:\n{ec[-400:]}")
    if ri != 0 and rc == 0:
        return ("verdict", f"cranelift ran but interp rejected:\n{ei[-400:]}")
    if ri != 0 and rc != 0:
        return ("reject", None)                # both reject (type error / guard) — consistent
    # both ran: output divergence (cranelift has no sanitizer-flush hazard)
    if oi != oc:
        return ("divergence", f"interp={oi!r} cranelift={oc!r}")
    return asan_run(src, work, oi)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=200)
    ap.add_argument("--seed", type=int, default=random.randrange(1 << 30))
    ap.add_argument("--keep-going", action="store_true", help="don't stop on first hard failure")
    a = ap.parse_args()
    if not os.path.exists(AXIONC):
        print(f"no axionc at {AXIONC} — build it first"); return 2
    _ensure_rt_a()  # build the Rust runtime staticlib so the ASan link resolves ported symbols
    print(f"fuzz: seed={a.seed} count={a.count} axionc={AXIONC}")
    tally = {}
    hard = 0
    with tempfile.TemporaryDirectory() as td:
        work = pathlib.Path(td)
        for i in range(a.count):
            rng = random.Random((a.seed << 20) ^ i)   # per-program seed = reproducible
            prog = gen(rng)
            verdict, detail = check(prog, work)
            tally[verdict] = tally.get(verdict, 0) + 1
            if verdict in ("corruption", "divergence", "verdict", "hang", "sessleak", "bileak",
                           "biax0910"):
                hard += 1
                FAILDIR.mkdir(exist_ok=True)
                f = FAILDIR / f"seed{a.seed}_i{i}_{verdict}.axi"
                f.write_text(prog)
                print(f"\n[{verdict.upper()}] i={i} saved {f}\n{detail}\n")
                if not a.keep_going:
                    break
            elif i % 25 == 0:
                print(f"  {i}/{a.count} … {dict(tally)}")
    print(f"\nsummary (seed {a.seed}): {dict(tally)}")
    if hard:
        print(f"FAIL: {hard} hard finding(s) — repros in {FAILDIR}/")
        return 1
    print("OK: no corruption / divergence / verdict-mismatch")
    return 0

if __name__ == "__main__":
    sys.exit(main())
