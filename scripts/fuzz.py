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

Two generators cover what the drop verifier does NOT model, so the ASan leg is the net there:
`gen_closure_values` (closures as values — returned, stored in Maybe/lists/tuples, duplicated,
passed through generic code, read back out, called repeatedly; each cell must have exactly one
owner) and `gen_heap_array` (arrays of heap elements: copies in and out, frees of replaced and
dropped elements). Run one alone with `--only closure_values` / `--only heap_array`.

`gen_closure_values` and `gen_sharing` (`--only sharing`) programs are safe by construction (see
`_safe_by_construction`). `gen_sharing` builds the ownership shapes the axmpv flagship broke: record
updates sharing heap fields with their base, conditional temps, callees that may return their
argument, closure tables, nested mixed conditionals, FFI with borrowed arguments. Its programs are
all safe, so a native AX0910/AX0911 refusal there is a hard `gap` finding, not a sound rejection,
and so is a native leak (`safeleak`). `gen_nested_patterns` is safe by construction too.

Native LEAKS while interp is clean are REPORTED (info) but not failed for the other generators.
AX0912 (heap-alias guard) and AX0910 (drop-verifier) rejections are counted separately — native
soundly refusing a value it cannot reclaim is correct-by-design. Every generated shape compiles
natively today, though, so `--max-refusals 0` (the nightly job) fails a run with any AX0910 refusal,
and `--save-refusals DIR` keeps each refused program with the verifier's message for triage; a verifier FALSE POSITIVE (rejecting safe code) is caught by the dedicated
0-FP corpus sweep in tests/verify.rs, not here. The `gen_tuple_consume` generator stresses the
consume-of-borrowed-interior-tuple-field class: OWNED variants must RUN + agree + be ASan-clean,
while BORROWED variants must be AX0910-rejected — and any variant the verifier MISSES compiles
and double-frees, which the ASan leg catches as corruption. Failing programs are saved to
fuzz-fail/ for a deterministic repro (the seed + index reproduce any run).

Run:  AXION_CLANG=clang ./scripts/fuzz.py [--count N] [--seed S] [--keep-going] [--only NAME]
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

OWN_PRE = """-- fuzz:ownership
data Rec = Rec { name :: String, tag :: Int, items :: List String }

idG :: a -> a
idG x = x

pickG :: Bool -> a -> a -> a
pickG b x y = if b then x else y

konst :: a -> a -> a
konst x y = x

orDefault :: String -> String -> String
orDefault d s = if strLen s == 0 then d else s

relJoin :: String -> String -> String
relJoin rel nm = if strLen rel == 0 then nm else strAppend (strAppend rel "/") nm

recLen :: Rec -> Int
recLen r = strLen (name r) + length (items r)

rename :: Rec -> String -> Rec
rename r n = r { name = n }

firstItem :: Rec -> String
firstItem r = case items r of
  Nil -> name r
  Cons x _ -> x

sumWith :: (String -> Int) -> List String -> Int
sumWith f xs = case xs of
  Nil -> 0
  Cons x rest -> f x + sumWith f rest

"""

def _own_str(rng):
    return rng.choice([f'"s{rng.randint(0, 9)}"', f"showInt {rng.randint(0, 999)}",
                       f"strAppend \"a\" (showInt {rng.randint(0, 99)})", '""'])

def _own_list(rng):
    xs = [_own_str(rng) for _ in range(rng.randint(0, 4))]
    return "Nil" if not xs else "".join(f"Cons ({x}) (" for x in xs) + "Nil" + ")" * len(xs)

def _own_term(rng, binds):
    """One Int term; may introduce a `let` (returned as a tuple) that later terms read."""
    k = rng.random()
    if k < 0.2:
        name = f"v{len(binds)}"
        kind = rng.choice(["S", "L", "R"])
        if kind == "S":
            val = _own_str(rng)
        elif kind == "L":
            val = _own_list(rng)
        else:
            val = f"Rec {{ name = {_own_str(rng)}, tag = {rng.randint(0, 9)}, items = {_own_list(rng)} }}"
        binds.append((name, kind))
        return ("let", name, val)
    if binds and rng.random() < 0.5:
        v, kind = rng.choice(binds)
        if kind == "S":
            return rng.choice([f"strLen {v}", f"strLen (idG {v})", f"strLen (orDefault \"d\" {v})",
                               f"strLen (relJoin \"\" {v})", f"strLen (pickG True {v} \"x\")"])
        if kind == "L":
            return rng.choice([f"length {v}", f"sumWith strLen {v}",
                               f"sumWith (\\s -> strLen (relJoin \"\" s)) {v}",
                               f"sumWith (\\s -> strLen (idG s)) {v}",
                               f"(case {v} of\n    Nil -> 0\n    Cons x _ -> strLen (orDefault \"d\" x))"])
        return rng.choice([f"recLen {v}", f"strLen (name {v})", f"strLen (firstItem {v})",
                           f"strLen (showInt (tag {v}))", f"recLen (rename {v} ({_own_str(rng)}))",
                           f"(case {v} of\n    Rec n t is -> strLen n + length is)"])
    # a where-local capturing a heap value
    if k < 0.45:
        s = _own_str(rng)
        return f"(let w = {s} in strLen (strAppend w w))"
    if k < 0.7:
        return rng.choice([f"strLen (konst ({_own_str(rng)}) ({_own_str(rng)}))",
                           f"strLen (pickG False ({_own_str(rng)}) ({_own_str(rng)}))",
                           f"length (idG ({_own_list(rng)}))"])
    return f"recLen (Rec {{ name = {_own_str(rng)}, tag = 1, items = {_own_list(rng)} }})"

def gen_ownership(rng):
    """Ownership shapes no other generator reaches: records with heap fields (read, updated by
    copy, case-extracted), let-bound heap values read again after borrowing calls, generic
    pass-through (`idG`, `pickG`, `konst`) and functions that may return a parameter WHOLE
    (`orDefault`, `relJoin`) over owned values, borrowed parameters and borrowed list elements,
    closures over them. Every program is safe: a divergence or an ASan finding is a hard failure;
    an AX0910 refusal is sound but counted, so a rise shows a missed reclamation."""
    binds = []
    lets, terms = [], []
    for _ in range(rng.randint(2, 6)):
        t = _own_term(rng, binds)
        if isinstance(t, tuple):
            lets.append(f"  let {t[1]} = {t[2]}")
        else:
            terms.append(t)
    for v, kind in binds:
        terms.append({"S": f"strLen {v}", "L": f"length {v}", "R": f"recLen {v}"}[kind])
    if not terms:
        terms.append("0")
    body = "\n".join(lets) + ("\n" if lets else "")
    body += "  putStrLn (showInt (" + " + ".join(terms) + "))\n"
    return OWN_PRE + "main :: IO ()\nmain = do\n" + body

CLOSURE_PRE = """-- fuzz:closures
sumL :: List Int -> Int
sumL xs = case xs of
  Nil -> 0
  Cons y r -> y + sumL r

call1 :: Maybe (Int -> Int) -> Int -> Int
call1 m x = case m of
  Just f -> f x
  Nothing -> 0

callAll :: List (Int -> Int) -> Int -> Int
callAll fs x = case fs of
  Nil -> 0
  Cons f r -> f x + callAll r x

applyAll :: List (Int -> Int) -> Int -> Int
applyAll fs x = case fs of
  Nil -> x
  Cons f r -> applyAll r (f x)

mkS :: String -> (Int -> Int)
mkS s = \\z -> strLen s + z

mkSL :: Int -> (Int -> Int)
mkSL n = let s = show n in \\z -> strLen s + z

mkL :: List Int -> (Int -> Int)
mkL xs = \\z -> sumL xs + z

mkI :: Integer -> (Integer -> Integer)
mkI b = \\z -> b + z

mkJ :: Int -> Maybe (Int -> Int)
mkJ n = let s = show n in Just (\\z -> strLen s + z)

mkT :: String -> Int -> (Int -> Int)
mkT nm k = let t = (nm, k) in \\z -> case t of
  (a, b) -> strLen a + b + z

store :: (Int -> Int) -> Maybe (Int -> Int)
store f = Just f

keepOr :: Maybe (Int -> Int) -> Maybe (Int -> Int) -> Maybe (Int -> Int)
keepOr a b = case a of
  Just f -> a
  Nothing -> b

getF :: Maybe (Int -> Int) -> (Int -> Int)
getF m = case m of
  Just f -> f
  Nothing -> \\z -> z

pick :: Bool -> (Int -> Int) -> (Int -> Int) -> (Int -> Int)
pick b f g = if b then f else g

idG :: a -> a
idG x = x

twice :: (Int -> Int) -> List (Int -> Int)
twice f = Cons f (Cons f Nil)

dupL :: a -> List a
dupL x = Cons x (Cons x Nil)

both :: (Int -> Int) -> (Int -> Int, Int -> Int)
both f = (f, f)

useBoth :: (Int -> Int) -> Int
useBoth f = case both f of
  (g, h) -> g 1 + h 2

pairWith :: a -> b -> (a, b)
pairWith x y = (x, y)

usePair :: (Int -> Int) -> Int -> Int
usePair f k = case pairWith f k of
  (g, n) -> g n

adders :: List Int -> List (Int -> Int)
adders ns = case ns of
  Nil -> Nil
  Cons n r -> Cons (\\z -> z + n) (adders r)

labels :: List String -> List (Int -> Int)
labels ss = case ss of
  Nil -> Nil
  Cons s r -> let t = strAppend s "!" in Cons (\\z -> strLen t + z) (labels r)

firstOr :: List (Int -> Int) -> Int -> Int
firstOr fs x = case fs of
  Cons f _ -> callAll (twice f) x
  Nil -> x

"""

def gen_closure_values(rng):
    """Closures as VALUES: capturing heap data (String / Integer / list / tuple), returned from
    functions, stored in Maybe / lists / tuples, duplicated (`twice`, `both`, generic `dupL`),
    passed through generic `idG`/`pairWith`, read back out of structures (`getF`), chosen
    (`pick`) and called repeatedly. Each closure cell is freed through its own destructor, copied
    through its own copier, and must have exactly one owner at every hand-off — the class whose
    double frees the drop verifier cannot see (it does not model what a closure owns), so the
    ASan leg is the net here. Every program prints Ints: interp == native, ASan/LSan-clean."""
    def S():
        return rng.choice([f'"{"".join(rng.choice("abc") for _ in range(rng.randint(0, 4)))}"',
                           f"show {rng.randint(0, 999)}",
                           f'strAppend "q" (show {rng.randint(0, 99)})'])
    def L():
        return "[" + ", ".join(str(rng.randint(0, 9)) for _ in range(rng.randint(0, 4))) + "]"
    def C(d=0):                                   # an expression of type Int -> Int
        k = rng.randint(0, 9)
        opts = [f"(\\z -> z + {k})", f"(\\z -> z * {k})", f"(mkSL {k})", f"(mkS ({S()}))",
                f"(mkL {L()})", f"(mkT ({S()}) {k})", "cs", "cl"]
        if d < 2:
            opts += [f"(pick {rng.choice(['True', 'False'])} {C(d + 1)} {C(d + 1)})",
                     f"(idG {C(d + 1)})", f"(getF {M(d + 1)})"]
        return rng.choice(opts)
    def M(d=0):                                   # Maybe (Int -> Int)
        opts = [f"(Just {C(d + 1)})", f"(store {C(d + 1)})", f"(mkJ {rng.randint(0, 99)})",
                "Nothing"]
        if d < 2:
            opts.append(f"(keepOr {M(d + 1)} {M(d + 1)})")
        return rng.choice(opts)
    def Ls(d=0):                                  # List (Int -> Int)
        opts = [f"[{C(d + 1)}, {C(d + 1)}]", f"(adders {L()})",
                f"(labels [{S()}, {S()}])", f"(twice {C(d + 1)})", f"(dupL {C(d + 1)})"]
        if d < 2:
            opts.append(f"(Cons {C(d + 1)} {Ls(d + 1)})")
        return rng.choice(opts)
    lines = [f"  let cs = mkS ({S()})", f"  let cl = mkL {L()}"]
    for i in range(rng.randint(2, 6)):
        x = rng.randint(0, 9)
        t = rng.randint(0, 9)
        if t == 0:
            e = f"{C()} {x}"
        elif t == 1:
            e = f"call1 {M()} {x}"
        elif t == 2:
            e = f"callAll {Ls()} {x}"
        elif t == 3:
            e = f"applyAll {Ls()} {x}"
        elif t == 4:
            e = f"useBoth {C()}"
        elif t == 5:
            e = f"usePair {C()} {x}"
        elif t == 6:
            e = f"firstOr {Ls()} {x}"
        elif t == 7:                              # a let-bound closure reused
            lines.append(f"  let f{i} = {C()}")
            e = f"f{i} {x} + f{i} {x + 1} + callAll [f{i}, f{i}] 1"
        elif t == 8:                              # a let-bound structure reused
            lines.append(f"  let m{i} = {M()}")
            e = f"call1 m{i} {x} + call1 m{i} {x + 2}"
        else:
            b = rng.randint(0, 50)
            e = f"strLen (showInteger (mkI (fromInt {b}) (fromInt {x})))"
        lines.append(f"  putStrLn (show ({e}))")
    lines.append("  putStrLn (show (cs 0 + cl 0))")
    return CLOSURE_PRE + "main :: IO ()\nmain = do\n" + "\n".join(lines) + "\n"

SHARING_PRE = """-- fuzz:sharing
data P = P { n :: Int, s :: String, xs :: List Int, t :: String }
data Act = Act String (P -> P)

sumL :: List Int -> Int
sumL l = case l of
  Nil -> 0
  Cons y r -> y + sumL r

m :: P -> Int
m p = n p + strLen (s p) + sumL (xs p) + strLen (t p)

mk :: Int -> P
mk k = P { n = k, s = "s" ++ showInt k, xs = [k, k + 1], t = "t" }

setN :: Int -> P -> P
setN k p = p { n = k }

setS :: P -> P
setS p = p { s = "z" ++ s p }

tag :: P -> P
tag p = p { n = 1 }

-- may return its argument whole: callers that keep using theirs must get a copy
bumpIf :: P -> P
bumpIf p = if n p > 3 then p { n = 0 } else p

acts :: List Act
acts = [ Act "a" (\\p -> setN 7 p), Act "b" (\\p -> tag (p { n = 9 })), Act "c" (\\p -> p { s = s p ++ "!" })
       , Act "d" (\\p -> p { xs = Cons 5 (xs p) }) ]

run :: String -> P -> P
run name p = goRun acts name p

goRun :: List Act -> String -> P -> P
goRun as2 name p = case as2 of
  Nil -> p
  Cons a rest -> case a of
    Act nm f -> if nm == name then f p else goRun rest name p

lbl :: Int -> String
lbl k = if k > 5 then "big" else if k > 2 then "n" ++ showInt k else ""

say :: Int -> IO ()
say k = ePutStrLn (if k > 4 then "k=" ++ showInt k else "small")

"""

SHARING_FFI = """foreign "libc.so.6" cStrlen = "strlen" :: String -> Int

"""

def gen_sharing(rng):
    """The ownership shapes the axmpv flagship broke (docs/memory: axion-axmpv-flagship): by-copy
    record updates SHARING heap fields with their base (base dying first, chains, results handed
    on, inside closures, on one branch of a conditional temp), a callee that may return its
    argument whole called in a let-bound arm with the argument reused after the join, closures
    in a `List Act` table called on borrowed records, nested mixed literal/built conditionals,
    fresh values moved on one branch only or returned on one path, ePutStrLn of a mixed
    conditional, and (native-only programs) borrowed arguments to a foreign call. Every program
    is SAFE value-semantics code, so a native AX0910/AX0911 refusal is a reclamation GAP (hard
    finding `gap`), and the instrumented ASan/LSan run is the soundness net."""
    ffi = rng.random() < 0.2
    F = ["n", "s", "xs", "t"]
    def val(f, k):
        return {"n": str(k), "s": rng.choice(['"w"', f"showInt {k}", '"x" ++ "y"']),
                "xs": rng.choice(["[1, 2]", f"Cons {k} Nil", "Nil"]), "t": rng.choice(['"t2"', '""'])}[f]
    def upd(base, k):
        fs = rng.sample(F, rng.randint(1, 2))
        return base + " { " + ", ".join(f"{f} = {val(f, k)}" for f in fs) + " }"
    def pe(d=0):                                  # an expression of type P
        k = rng.randint(0, 9)
        opts = [f"(mk {k})"]
        if d < 2:
            inner = pe(d + 1)
            opts += [f"(setN {k} {inner})", f"(setS {inner})", f"(bumpIf {inner})", f"(tag {inner})",
                     f"(run \"{rng.choice('abcdx')}\" {inner})", f"({upd(inner, k)})"]
        return rng.choice(opts)
    K = lambda: rng.randint(0, 6)
    funs, calls = [], []
    for i in range(rng.randint(3, 6)):
        f1, f2 = rng.choice(F), rng.choice(F)
        c, c2 = K(), K()
        tmpl = rng.randint(0, 9 if ffi else 8)
        name = f"f{i}"
        if tmpl == 0:     # G: owning callee in a let-bound arm, argument reused after the join
            body = f"let p2 = if k > {c} then {rng.choice(['bumpIf p0', 'tag p0', 'setS p0', f'run \"{rng.choice("abcd")}\" p0'])} else p0 in m p2 + m p0"
        elif tmpl == 1:   # J: conditional temp, updated by copy on one branch and handed on
            body = (f"let p = if k > {c} then {upd('p0', c)} else p0 in "
                    f"if n p > {c2} then m ({rng.choice(['tag', 'setS', 'bumpIf'])} ({upd('p', c2)})) else m p")
        elif tmpl == 2:   # base-dies-first / chains: uses in random order
            uses = ["m b0", "m b1", "m b2", "strLen (s b1)", "sumL (xs b2)"]
            rng.shuffle(uses)
            body = (f"let b0 = mk k in let b1 = {upd('b0', c)} in let b2 = {upd('b1', c2)} in "
                    + " + ".join(uses[:rng.randint(2, 5)]))
        elif tmpl == 3:   # C: closure table on a borrowed record, the record used again
            body = f"m (run \"{rng.choice('abcdx')}\" p0) + m (run \"{rng.choice('abcd')}\" p0) + m p0"
        elif tmpl == 4:   # F: nested mixed conditional strings
            body = (f"strLen (lbl k) + strLen (\"x\" ++ (if k > {c} then \"a\" else if k > {c2} "
                    f"then showInt k ++ s p0 else \"\"))")
        elif tmpl == 5:   # B: a fresh call result returned on one path, dead on the other
            body = f"strLen (let v = s (setS p0) in if k > {c} then v else \"\")"
        elif tmpl == 6:   # a fresh update moved on one branch, only read on the other
            body = (f"let p1 = {upd('p0', c)} in if k > {c2} then m (run \"{rng.choice('abcd')}\" p1) "
                    f"else n p1 + strLen (s p1)")
        elif tmpl == 7:   # update of a record field read back, both live
            body = f"let q = {upd('p0', c)} in m q + m p0 + strLen ({f1 if f1 in ('s', 't') else 's'} q)"
        elif tmpl == 8:   # value threaded through a loop of updates
            body = f"m (loopU k p0)"
        else:             # H (native-only): borrowed arg to a foreign call, returned on one path
            body = f"strLen (let nm = \"f\" ++ showInt k ++ s p0 in let l = cStrlen nm in if l > {c + 3} then nm else \"\")"
        funs.append(f"{name} :: P -> Int -> Int\n{name} p0 k = {body}\n")
        for _ in range(rng.randint(1, 2)):
            calls.append(f"{name} {pe()} {rng.randint(0, 9)}")
    loop_fn = ("loopU :: Int -> P -> P\nloopU k p = if k <= 0 then p else loopU (k - 1) "
               + "(" + rng.choice(["setN k p", "p { n = n p + k }", "setS p", "tag (p { xs = Cons k Nil })"]) + ")\n")
    lines = [f"  putStrLn (showInt ({c}))" for c in calls]
    lines.insert(rng.randint(0, len(lines)), f"  say {rng.randint(0, 9)}")
    pre = SHARING_PRE + (SHARING_FFI if ffi else "")
    return (pre + loop_fn + "\n" + "\n".join(funs) + "\nmain :: IO ()\nmain = do\n"
            + "\n".join(lines) + "\n")

NESTED_PRE = """-- fuzz:nested
data Sh = Dot | Box Int Int | Tag String Sh

rLS :: List String -> String
rLS xs = case xs of
  Cons a rest -> a ++ "," ++ rLS rest
  Nil -> "."

rLI :: List Int -> String
rLI xs = case xs of
  Cons a rest -> showInt a ++ "," ++ rLI rest
  Nil -> "."

rSh :: Sh -> String
rSh s = case s of
  Dot -> "dot"
  Box w h -> "box" ++ showInt w ++ "x" ++ showInt h
  Tag t inner -> t ++ "<" ++ rSh inner ++ ">"

rMS :: Maybe String -> String
rMS m = case m of
  Just t -> "J" ++ t
  Nothing -> "N"

rMSh :: Maybe Sh -> String
rMSh m = case m of
  Just t -> "J" ++ rSh t
  Nothing -> "N"

rMIS :: Maybe (Int, String) -> String
rMIS m = case m of
  Just p -> case p of
    (k, t) -> "J" ++ showInt k ++ t
  Nothing -> "N"

rP :: (Maybe String, Int) -> String
rP p = case p of
  (m, k) -> rMS m ++ "/" ++ showInt k

"""

def gen_nested_patterns(rng):
    """Nested patterns (compiled to nested single-level cases before Auto-Drop): random EXHAUSTIVE
    `case`s with constructor, tuple and literal sub-patterns at several depths over lists, Maybe,
    tuples and a sum type with String payloads; arm bodies move a String payload out, combine or
    drop payloads; the final catch-all binds the scrutinee (or names it) and reads it whole — the
    row-by-row (`sequential`) path. Every program is SAFE value-semantics code: a native refusal is
    a gap, and the interpreter (which matches the AST directly) is the oracle for first-match.
    Some sub-patterns are or-patterns `(p1 | p2)` (binder-free, distinct heads)."""
    # types: leaves "Int"/"String"; ("L", t) list; ("M", t) Maybe; ("T", [a, b]) tuple; "Sh"
    TYPES = [("L", "String"), ("L", "Int"), "Sh", ("M", "Sh"), ("M", ("T", ["Int", "String"])),
             ("T", [("M", "String"), "Int"])]
    def tname(t):
        if t in ("Int", "String", "Sh"):
            return t
        if t[0] == "L":
            return f"List {tname(t[1])}"
        if t[0] == "M":
            inner = tname(t[1])
            return f"Maybe ({inner})" if " " in inner or t[1][0] == "T" else f"Maybe {inner}"
        return "(" + ", ".join(tname(x) for x in t[1]) + ")"
    def render(v, t):
        r = {"String": v, "Int": f"showInt {v}", "Sh": f"rSh {v}"}.get(t if isinstance(t, str) else None)
        if r:
            return r
        key = {("L", "String"): "rLS", ("L", "Int"): "rLI", ("M", "Sh"): "rMSh",
               ("M", "String"): "rMS"}.get(t if t[0] != "T" and not isinstance(t[1], tuple) else None)
        if key:
            return f"{key} {v}"
        if t == ("M", ("T", ["Int", "String"])):
            return f"rMIS {v}"
        if t == ("T", [("M", "String"), "Int"]):
            return f"rP {v}"
        return '"?"'
    ctr = [0]
    def fresh():
        ctr[0] += 1
        return f"v{ctr[0]}"
    def pat(t, depth, binds):
        """a pattern of type `t`; appends (var, type) to `binds`. Returns (text, atomic)."""
        # an or-pattern `(p1 | p2)`: two binder-free alternatives with different head
        # constructors/literals (so neither makes the other redundant)
        if depth > 0 and t != "String" and (t in ("Int", "Sh") or t[0] in ("L", "M")) \
                and rng.random() < 0.15:
            b1, b2 = [], []
            p1, _ = pat_one(t, depth, b1)
            p2, _ = pat_one(t, depth, b2)
            h1, h2 = p1.split()[0], p2.split()[0]
            if not b1 and not b2 and h1 != h2 and "_" not in (h1, h2) \
                    and not h1[0].islower() and not h2[0].islower():
                return f"({p1} | {p2})", True
        return pat_one(t, depth, binds)
    def pat_one(t, depth, binds):
        r = rng.random()
        if depth <= 0 or r < 0.25:
            if rng.random() < 0.6:
                v = fresh()
                binds.append((v, t))
                return v, True
            return "_", True
        if t == "Int":
            return str(rng.randint(0, 2)), True
        if t == "String":
            v = fresh()
            binds.append((v, t))
            return v, True
        def sub(t2):
            txt, atomic = pat(t2, depth - 1, binds)
            return txt if atomic else f"({txt})"
        if t == "Sh":
            c = rng.choice(["Dot", "Box", "Tag"])
            if c == "Dot":
                return "Dot", True
            if c == "Box":
                return f"Box {sub('Int')} {sub('Int')}", False
            return f"Tag {sub('String')} {sub('Sh')}", False
        if t[0] == "L":
            if rng.random() < 0.3:
                return "Nil", True
            return f"Cons {sub(t[1])} {sub(t)}", False
        if t[0] == "M":
            if rng.random() < 0.25:
                return "Nothing", True
            return f"Just {sub(t[1])}", False
        parts = [pat(x, depth - 1, binds)[0] for x in t[1]]
        return "(" + ", ".join(parts) + ")", True
    def value(t, depth=2):
        if t == "Int":
            return str(rng.randint(0, 2))
        if t == "String":
            return rng.choice(['"a"', '"bc"', 'showInt 7', '"d" ++ "e"'])
        if t == "Sh":
            c = rng.choice(["Dot", "Box", "Tag"] if depth > 0 else ["Dot", "Box"])
            if c == "Dot":
                return "Dot"
            if c == "Box":
                return f"(Box {value('Int')} {value('Int')})"
            return f"(Tag ({value('String')}) {value('Sh', depth - 1)})"
        if t[0] == "L":
            n = rng.randint(0, 3)
            out = "Nil"
            for _ in range(n):
                out = f"(Cons ({value(t[1], depth - 1)}) {out})"
            return out
        if t[0] == "M":
            return "Nothing" if rng.random() < 0.3 else f"(Just ({value(t[1], depth - 1)}))"
        return "(" + ", ".join(value(x, depth - 1) for x in t[1]) + ")"
    funcs, calls = [], []
    for fi in range(rng.randint(1, 3)):
        t = rng.choice(TYPES)
        name = f"f{fi}"
        arms = []
        def refutable(txt):
            # an arm before the final catch-all must be able to fail, or every later arm is
            # unreachable (AX0203, a warning the interpreter prints on stdout)
            return any(c[0].isupper() or c[0].isdigit() for c in txt.replace("(", " ").replace(")", " ").replace(",", " ").split())
        for ai in range(rng.randint(1, 4)):
            for _ in range(20):
                binds = []
                ptxt, _ = pat(t, rng.randint(1, 3), binds)
                if refutable(ptxt):
                    break
            else:
                continue
            heap = [(v, bt) for v, bt in binds if bt == "String"]
            embed = [(v, bt) for v, bt in binds if bt in ("String", "Sh", ("L", "String"))]
            mode = rng.random()
            if embed and mode < 0.2:
                # store a payload in a NEW value (`Cons v Nil`, `Just v`): when the caller keeps
                # the scrutinee (below) the payload is a part of a borrowed value — the compiler
                # copies it rather than give it two owners
                v, bt = rng.choice(embed)
                new_val = {"String": f'rLS (Cons {v} Nil)', "Sh": f"rMSh (Just {v})",
                           ("L", "String"): f'rLS (Cons "k" {v})'}[bt]
                body = f'"b{ai}:" ++ {new_val}'
            elif heap and mode < 0.45:
                body = heap[0][0]                                   # move a payload out
            elif binds and mode < 0.8:
                pick = rng.sample(binds, min(len(binds), rng.randint(1, 2)))
                body = f'"a{ai}:" ++ ' + ' ++ "|" ++ '.join(f"({render(v, bt)})" for v, bt in pick)
            else:
                body = f'"a{ai}"'                                   # drop every payload
            arms.append(f"  {ptxt} -> {body}")
        # the final catch-all: binds the scrutinee, names the parameter, or ignores it
        c = rng.random()
        if c < 0.4:
            w = fresh()
            arms.append(f'  {w} -> "d:" ++ {render(w, t)}')
        elif c < 0.7:
            arms.append(f'  _ -> "e:" ++ {render("x", t)}')
        else:
            arms.append('  _ -> "z"')
        funcs.append(f"{name} :: {tname(t)} -> String\n{name} x = case x of\n" + "\n".join(arms) + "\n")
        if rng.random() < 0.5:
            # the caller keeps its value: the parameter is only read (borrowed) unless an arm
            # moves a top-level payload out (then the front end rejects the reuse — consistently)
            y = f"y{fi}"
            calls.append(f"  let {y} = {value(t)}")
            for _ in range(rng.randint(1, 2)):
                calls.append(f"  putStrLn ({name} {y})")
            calls.append(f"  putStrLn ({render(y, t)})")
        else:
            for _ in range(rng.randint(2, 4)):
                calls.append(f"  putStrLn ({name} {value(t)})")
    return NESTED_PRE + "\n".join(funcs) + "\nmain :: IO ()\nmain = do\n" + "\n".join(calls) + "\n"

HEAP_ARRAY_PRE = """-- fuzz:heap-arrays
data R = R String Int

sumL :: List Int -> Int
sumL xs = case xs of
  Nil -> 0
  Cons y r -> y + sumL r

mS :: String -> Int
mS s = strLen s

mI :: Integer -> Int
mI x = strLen (showInteger x)

mL :: List Int -> Int
mL xs = sumL xs

mT :: (String, Int) -> Int
mT t = case t of
  (a, b) -> strLen a + b

mM :: Maybe String -> Int
mM m = case m of
  Just s -> strLen s + 1
  Nothing -> 0

mR :: R -> Int
mR r = case r of
  R s n -> strLen s + n

"""

# per element type: (Axion type, measure fn, literal generator(rng, i-expr or None))
def _ha_types():
    return {
        "S": ("String", "mS", lambda rng, i: rng.choice([f'"{"x" * rng.randint(0, 3)}"',
                                                         f"show {i}", f'strAppend "a" (show {i})'])),
        "I": ("Integer", "mI", lambda rng, i: rng.choice([f"fromInt {i}", f"fromInt {i} * fromInt 1000"])),
        # (no `[]`: a `let`-bound array is generalized before its literals default, so a later
        # `setArray a i []` gets an element type nothing fixes — natively refused, AX0914)
        "L": ("List Int", "mL", lambda rng, i: rng.choice([f"[{i}, {i}]", f"[{i}]", f"[1, {i}, 3]"])),
        "T": ("(String, Int)", "mT", lambda rng, i: f"(show {i}, {i})"),
        "M": ("Maybe String", "mM", lambda rng, i: rng.choice([f"Just (show {i})", "Nothing"])),
        "R": ("R", "mR", lambda rng, i: f"R (show {i}) {i}"),
    }

def gen_heap_array(rng):
    """Native arrays of HEAP elements (String / Integer / list / tuple / Maybe / record): the
    array owns its elements — newArray/setArray store copies, getArray returns a copy, setArray
    frees the replaced element, dropping the array frees every element. Shapes: setArray chains
    (shadowing and not), repeated reads of one slot, a `%1` fill loop, a borrowed sum loop, an
    array consumed by a `%1` function, and an array returned by a function. Every program prints
    Ints: interp == native, ASan/LSan-clean."""
    key, (T, meas, lit) = rng.choice(sorted(_ha_types().items()))
    if " " in T and not T.startswith("("):
        T = f"({T})"                              # `Array (List Int)`
    n = rng.randint(1, 12)
    helpers = (
        f"fillA :: Array {T} %1 -> Int -> Int -> Array {T}\n"
        f"fillA a i n = if i >= n then a else fillA (setArray a i ({lit(rng, 'i')})) (i + 1) n\n"
        f"sumA :: Array {T} -> Int -> Int -> Int\n"
        f"sumA a i n = if i >= n then 0 else {meas} (getArray a i) + sumA a (i + 1) n\n"
        f"lenC :: Array {T} %1 -> Int\nlenC a = lenArray a\n"
        f"mkA :: Int -> Array {T}\nmkA k = fillA (newArray k ({lit(rng, 0)})) 0 k\n"
    )
    # the initial value must fix the element type: `newArray n []` lets `let` generalize the
    # binding to `Array (List a)`, which native builds refuse (AX0914, sound) — the later
    # `setArray`s may store `[]`/`Nothing`, the array's type is fixed by then
    init = lit(rng, rng.randint(0, 9))
    while init == "Nothing":
        init = lit(rng, rng.randint(0, 9))
    lines = [f"  let a0 = newArray {n} ({init})"]
    cur = "a0"
    for j in range(rng.randint(0, 5)):
        nxt = f"a{j + 1}"
        lines.append(f"  let {nxt} = setArray {cur} {rng.randint(0, n - 1)} ({lit(rng, rng.randint(0, 99))})")
        cur = nxt
    for _ in range(rng.randint(1, 5)):
        t = rng.randint(0, 5)
        idx = rng.randint(0, n - 1)
        if t == 0:
            e = f"{meas} (getArray {cur} {idx}) + {meas} (getArray {cur} {idx})"
        elif t == 1:
            e = f"sumA {cur} 0 {n}"
        elif t == 2:
            e = f"lenArray {cur}"
        elif t == 3:
            k = rng.randint(0, 8)
            e = f"sumA (mkA {k}) 0 {k}"
        elif t == 4:
            e = f"lenC (fillA (newArray {n} ({lit(rng, 1)})) 0 {n})"
        else:
            e = f"{meas} (getArray (mkA {n}) {idx})"
        lines.append(f"  putStrLn (show ({e}))")
    if rng.random() < 0.5:
        lines.append(f"  putStrLn (show (lenC {cur}))")
    return HEAP_ARRAY_PRE + helpers + "main :: IO ()\nmain = do\n" + "\n".join(lines) + "\n"

LOCALS_PRE = """-- fuzz:locals
lenL :: List String -> Int
lenL xs = case xs of
  Nil -> 0
  Cons _ rest -> 1 + lenL rest

catL :: List String -> String
catL xs = case xs of
  Nil -> "."
  Cons a rest -> a ++ "," ++ catL rest

"""

def gen_local_fns(rng):
    """Local functions: `let`-bound ones (lifted to `where`-locals by axionc/src/letlift.rs, with
    the variables they use passed as extra parameters) and `where`-locals — recursive, mutually
    recursive, with guards and several clauses, using a `case` binder, nested, inside a
    `where`-local, in a `do` block, reading / returning / storing parts of heap parameters (the two
    pre-existing `where` bugs: a read-only parameter owned by the local, `otherwise` in a guard),
    and called from a lambda (also a lambda parameter named like a captured variable).
    Only shapes that compile natively are generated, so every program is SAFE: a native refusal,
    a leak or a front-end rejection is a finding."""
    W = ["ab", "cde", "f", "ghij", "", "kl"]
    lit = lambda: '"' + rng.choice(W) + '"'
    C = lambda: rng.randint(0, 5)
    funs, lines = [], []
    for i in range(rng.randint(2, 5)):
        n, c, c2 = f"t{i}", C(), C()
        tmpl = rng.randint(0, 14)
        ret = "Int"
        if tmpl == 0:     # recursive let function using a parameter
            extra = rng.choice(["lenL xs", "strLen tag", "0"])
            body = (f"\n  let go acc ys = case ys of\n        Nil -> acc + strLen tag\n"
                    f"        Cons y rest -> go (acc + strLen y + {c}) rest\n  in go k xs + {extra}")
        elif tmpl == 1:   # mutually recursive, String results
            ret = "String"
            body = (f"\n  let ev j = if j <= 0 then tag ++ \":e\" else od (j - 1)\n"
                    f"      od j = if j <= 0 then catL xs else ev (j - 1)\n  in ev (k + {c})")
        elif tmpl == 2:   # guards + several clauses; returns the captured String on one path
            ret = "String"
            alt = rng.choice(["tag ++ \"!\"", lit(), "catL xs"])
            body = (f"\n  let kind 0 = {lit()}\n      kind j\n        | j < {c2} = tag\n"
                    f"        | otherwise = {alt}\n  in kind 0 ++ kind {c} ++ kind (k + 1)")
        elif tmpl == 3:   # captures `case` binders (an element and the rest of the list)
            body = (f" case xs of\n  Nil -> k\n  Cons h rest ->\n"
                    f"    let f j = strLen h + j + lenL rest\n    in f {c} + f k")
        elif tmpl == 4:   # where-local only READS a list parameter, called twice
            body = (f" h xs + h xs + lenL xs\n  where\n    h ys = case ys of\n"
                    f"      Nil -> k\n      Cons y _ -> strLen y + k + {c}")
        elif tmpl == 5:   # where-local RETURNS an element (or the captured tag / a literal)
            ret = "String"
            dflt = rng.choice(["tag", lit()])
            body = (f" pickW xs ++ \"/\" ++ catL xs\n  where\n    pickW ys = case ys of\n"
                    f"      Nil -> {dflt}\n      Cons y _ -> y")
        elif tmpl == 6:   # where-local STORES elements in a new list (owns its argument)
            body = (f" lenL (cp xs) + k\n  where\n    cp ys = case ys of\n      Nil -> Nil\n"
                    f"      Cons y rest -> Cons y (cp rest)")
        elif tmpl == 7:   # let function inside a where-local's guard, `otherwise`
            body = (f" helper k\n  where\n    helper m\n"
                    f"      | m > {c} = let twice j = j + j + lenL xs in twice m\n"
                    f"      | otherwise = strLen tag + {c2}")
        elif tmpl == 8:   # nested lets: the inner function uses the outer one's parameter
            body = (f"\n  let outer a = (let inner b = a * {c} + b + strLen tag in inner k)\n"
                    f"  in outer (lenL xs)")
        elif tmpl == 9:   # let function storing its argument and a captured String in a new list
            body = (f"\n  let wrap s = Cons s (Cons tag Nil)\n  in lenL (wrap {lit()}) + lenL xs")
        elif tmpl == 10:  # a lambda calling a where-local that captures a String
            ret = "String"
            body = (f" catL (map (\\s -> tagIt s) xs)\n  where\n"
                    f"    tagIt s = tag ++ \":\" ++ s ++ showInt (k + {c})")
        elif tmpl == 11:  # a lambda calling a let function
            ret = "String"
            body = (f"\n  let wrap s = s ++ tag ++ showInt {c}\n  in catL (map (\\s -> wrap s) xs)")
        elif tmpl == 12:  # a let function inside a lambda, capturing the lambda's parameter
            ret = "String"
            body = (f" catL (map (\\s -> let dup j = s ++ showInt j in dup k ++ dup {c}) xs)")
        elif tmpl == 13:  # the lambda's parameter has the name of a variable the local captures
            ret = "String"
            body = (f" catL (map (\\tag -> tagIt tag) xs)\n  where\n"
                    f"    tagIt s = tag ++ \"/\" ++ s")
        else:             # a lambda calling a local that returns its argument or a captured String
            ret = "String"
            body = (f" catL (map (\\s -> pickW s) xs)\n  where\n"
                    f"    pickW s = if strLen s > {c2 % 3} then s else tag")
        funs.append(f"{n} :: List String -> String -> Int -> {ret}\n{n} xs tag k ={body}\n")
        for _ in range(rng.randint(1, 2)):
            xs = rng.choice([f'(words "{rng.choice(W)} {rng.choice(W)} {rng.choice(W)}")', "Nil",
                             f"(Cons {lit()} Nil)"])
            tag = rng.choice([lit(), f'("t" ++ showInt {C()})'])
            call = f"{n} {xs} {tag} {C()}"
            lines.append(f"  putStrLn ({call})" if ret == "String" else f"  putStrLn (showInt ({call}))")
    if rng.random() < 0.5:        # a let function in a do block
        a, b = C(), C()
        at = rng.randint(0, len(lines))
        lines[at:at] = [f"  let tw j = j * {a} + j", f"  putStrLn (showInt (tw {b} + tw {a}))"]
    return LOCALS_PRE + "\n".join(funs) + "\nmain :: IO ()\nmain = do\n" + "\n".join(lines) + "\n"

TUPLES_PRE = """-- fuzz:tuples
catL :: List String -> String
catL xs = case xs of
  Nil -> "."
  Cons a rest -> a ++ "," ++ catL rest

mkPs :: Int -> List (String, Int)
mkPs k = [(showInt k ++ "a", k + 1), ("bb", k + 2), (showInt k, k + 3)]

pairK :: Int -> (String, Int)
pairK n = (showInt n ++ "p", n)

"""

def gen_tuple_acc(rng):
    """`fst`/`snd` and parts of tuples: on a variable they only read it (an inline `case`), so the
    tuple stays usable — read twice, read then stored whole on one branch, a part stored in a new
    list while the caller keeps the list, a predicate reading the pair, a part returned from a
    search; on a temporary they go to the prelude functions, which free it; and a part moved out
    of a temporary tuple, bound and used. Only shapes that compile natively are generated, so every
    program is SAFE: a native refusal, a leak or a front-end rejection is a finding.
    Known limits left out (refused natively, never miscompiled): a tuple stored on one branch of a
    non-tail `if`; a `where`-local owning a list its caller reuses; `map fst ps` / a lambda over
    `ps` with `ps` used again; `snd (tag, …)` on a tuple holding a borrowed String; a part or a
    captured String chosen by an `if`; a pair of Strings stored after its parts are read."""
    W = ["ab", "cde", "f", ""]
    lit = lambda: '"' + rng.choice(W) + '"'
    C = lambda: rng.randint(0, 5)
    funs, lines = [], []
    pair = "(String, Int) -> String -> Int -> String"
    for i in range(rng.randint(2, 5)):
        n, c = f"t{i}", C()
        tmpl = rng.randint(0, 5)
        sig, call = "List (String, Int) -> String -> Int -> String", f"{n} (mkPs {C()}) {lit()} {C()}"
        if tmpl == 0:     # predicate reading the pair; the kept parts read
            body = f" catL (map fst (filter (\\p -> snd p > {c} + k) ps))"
        elif tmpl == 1:   # parts read twice from one tuple
            sig, call = pair, f"{n} (pairK {C()}) {lit()} {C()}"
            body = f" fst ps ++ tag ++ showInt (snd ps + k) ++ fst ps"
        elif tmpl == 2:   # read, then stored whole on one branch (in tail position)
            sig, call = pair, f"{n} (pairK {C()}) {lit()} {C()}"
            funs.append(f"keep{i} :: (String, Int) -> List (String, Int)\n"
                        f"keep{i} y = if snd y > {c} then Cons y Nil else Nil\n")
            body = f" catL (map fst (keep{i} ps)) ++ tag"
        elif tmpl == 3:   # a part stored in a new list over a borrowed list, the list used again
            funs.append(f"firsts{i} :: List (String, Int) -> String -> List String\n"
                        f"firsts{i} xs tag = case xs of\n  Nil -> Nil\n"
                        f"  Cons y ys -> Cons (fst y ++ tag) (firsts{i} ys tag)\n")
            body = f" catL (firsts{i} ps tag) ++ showInt (length ps + k)"
        elif tmpl == 4:   # a part moved out of a temporary tuple, bound and used
            body = f"\n  let s = (case pairK (k + {c}) of (a, _) -> a)\n  in s ++ tag ++ fst (pairK k)"
        else:             # the matching element's part, returned from a search over the list
            body = (f" look{i} ps\n  where\n    look{i} xs = case xs of\n      Nil -> tag\n"
                    f"      Cons y ys -> if snd y == k + {c} then fst y else look{i} ys")
        funs.append(f"{n} :: {sig}\n{n} ps tag k ={body}\n")
        lines.append(f"  putStrLn ({call})")
    return TUPLES_PRE + "\n".join(funs) + "\nmain :: IO ()\nmain = do\n" + "\n".join(lines) + "\n"

def gen_refine(rng):
    """Integer refinements (axionc/src/refine.rs): random conditions, often subtly wrong (off by
    one, the wrong branch, a sum that wraps near the largest Int, division), guarding a call to a
    refined `get` whose access the checker then emits WITHOUT its bounds check; loops with random
    starts, steps and offsets; a refined result with a random body. The checker must refuse
    (AX0600) every program whose access could go out of bounds: an accepted one must agree with
    the interpreter (which always checks) and be ASan-clean — an interpreter bounds abort that
    native does not reproduce is an unsound proof."""
    big = [9223372036854775807, 4611686018427387904, -9223372036854775807, 9223372036854775806]
    val = lambda: rng.choice(big) if rng.random() < 0.15 else rng.randint(-3, 14)
    lit = lambda v: f"({v})" if v < 0 else str(v)
    C = lambda: rng.randint(-2, 3)
    def iexpr():
        return rng.choice(["x", "y", "x + {c}", "y - {c}", "x + y", "lenArray a - {k}",
                           "x / 2", "x `mod` 4", "x + (y - x) / 2", "{k}", "x * 2", "y + 1"]
                          ).format(c=rng.randint(0, 3), k=rng.randint(0, 3))
    def atom():
        return rng.choice(["0 <= {e}", "{e} < lenArray a", "{e} <= lenArray a", "{e} >= 0",
                           "{e} > {c}", "x < y", "y <= lenArray a", "x >= 0", "0 < x",
                           "{e} /= {c}", "{e} == {c}"]).format(e=iexpr(), c=C())
    def cond():
        r = rng.random()
        if r < 0.5:
            return f"{atom()} && {atom()}"
        if r < 0.7:
            return f"{atom()} && {atom()} && {atom()}"
        if r < 0.85:
            return atom()
        return f"({atom()} || {atom()}) && {atom()}"
    funs, calls = [], []
    for i in range(rng.randint(1, 2)):   # one rejected function rejects the whole program
        n = f"f{i}"
        t = rng.randint(0, 5)
        if t == 5:      # the right guard, or one off by one (`<=`, a shifted index)
            e = iexpr()
            op = rng.choice(["<", "<", "<="])
            idx = rng.choice([e, e, f"{e} + 1", f"{e} - 1"])
            lo = rng.choice(["0 <= " + e, "0 <= " + e, "0 < " + e, e + " > (0 - 1)", e + " >= 1"])
            funs.append(f"{n} :: Array Int -> Int -> Int -> Int\n"
                        f"{n} a x y = if {lo} && {e} {op} lenArray a then get a ({idx}) else 9\n")
        elif t == 0:    # an `if` guarding the access
            funs.append(f"{n} :: Array Int -> Int -> Int -> Int\n"
                        f"{n} a x y = if {cond()} then get a ({iexpr()}) else 0 - 1\n")
        elif t == 1:    # guards, the access in a later one
            funs.append(f"{n} :: Array Int -> Int -> Int -> Int\n{n} a x y\n"
                        f"  | {atom()} = 0 - 2\n  | {cond()} = get a ({iexpr()})\n  | otherwise = 7\n")
        elif t == 2:    # a counting loop with a random start, step and offset
            d, st, o = rng.randint(-1, 2), rng.choice([1, 1, 2, 3]), rng.randint(-1, 2)
            funs.append(f"{n} :: a:Array Int -> {{i:Int | 0 <= i}} -> Int -> Int\n"
                        f"{n} a i acc = if i < lenArray a - {d} then {n} a (i + {st}) "
                        f"(acc + get a (i + {lit(o)})) else acc\n")
            calls.append(f"  putStrLn (showInt ({n} arr {rng.randint(0, 3)} 0))")
            continue
        elif t == 3:    # a let-bound index
            c = cond()
            if rng.random() < 0.5:
                c = c.replace("x", "j")
            funs.append(f"{n} :: Array Int -> Int -> Int -> Int\n"
                        f"{n} a x y =\n  let j = {iexpr()} in\n  if {c} then get a j else 3\n")
        else:           # a refined result, then used as an index
            body = rng.choice(["if x < 0 then 0 else if x > hi then hi else x",
                               "if x < 0 then 0 else if x >= hi then hi else x",
                               "if x <= 0 then 0 else if x > hi then hi - 1 else x",
                               "if x < 0 then 0 else x `mod` (hi + 1)",
                               "if x > hi then hi else x"])
            funs.append(f"clamp{i} :: Int -> {{hi:Int | 0 <= hi}} -> {{r:Int | 0 <= r && r <= hi}}\n"
                        f"clamp{i} x hi = {body}\n"
                        f"{n} :: Array Int -> Int -> Int -> Int\n"
                        f"{n} a x y = if lenArray a > {rng.randint(0, 2)} then "
                        f"get a (clamp{i} x (lenArray a - 1)) else 5\n")
        for _ in range(rng.randint(1, 3)):
            calls.append(f"  putStrLn (showInt ({n} arr {lit(val())} {lit(val())}))")
    length = rng.randint(0, 9)
    return ("-- fuzz:refine\nget :: a:Array Int -> {i:Int | 0 <= i && i < len a} -> Int\n"
            "get a i = getArray a i\n\n" + "\n".join(funs)
            + f"\nmain :: IO ()\nmain = do\n  let arr = newArray {length} 4\n" + "\n".join(calls) + "\n")

def gen_simd(rng):
    """SIMD vector types (axionc/src/simd.rs): random lane arithmetic (`+ - * /`, min/max, fma,
    sqrt), vectors as parameters, results, loop accumulators and `if` joins, range-checked loads
    and stores at random (sometimes out-of-range) indices, and lanes at random indices. The
    interpreter models the lanes; the native backends keep vectors in registers (LLVM) or as
    lanes (Cranelift) and must print the same bits, abort on the same out-of-range accesses, and
    be ASan-clean (an unchecked lane access past the array is a heap-buffer-overflow)."""
    name, n, fl = rng.choice([("F64x4", 4, True), ("F64x2", 2, True),
                              ("I64x4", 4, False), ("I64x2", 2, False)])
    lc, elem = name.lower(), ("Float" if fl else "Int")
    show = "showFloat" if fl else "showInt"
    def lit():
        if fl:
            return rng.choice(["0.5", "1.0", "2.0", "3.25", "0.0", "1.5", "7.0", "0.125", "1.0e-3"])
        v = rng.randint(-6, 9)
        return f"({v})" if v < 0 else str(v)
    def idx():
        return str(rng.choice([0, 0, 1, 2, n - 1, n, rng.randint(0, 12)]))
    def vexpr(d, env):
        r = rng.random()
        if d <= 0 or r < 0.25:
            return rng.choice([f"({lc} {' '.join(lit() for _ in range(n))})",
                               f"(splat{name} {lit()})"] + env)
        if r < 0.55:
            ops = ["+", "-", "*"] + (["/"] if fl else [])
            return f"({vexpr(d - 1, env)} {rng.choice(ops)} {vexpr(d - 1, env)})"
        if r < 0.65:
            return f"({rng.choice(['min', 'max'])}{name} {vexpr(d - 1, env)} {vexpr(d - 1, env)})"
        if r < 0.72 and fl:
            return f"(fma{name} {vexpr(d - 1, env)} {vexpr(d - 1, env)} {vexpr(d - 1, env)})"
        if r < 0.76 and fl:
            x = vexpr(d - 1, env)
            return f"(sqrt{name} ({x} * {x}))"
        if r < 0.86:
            return f"(if sum{name} {vexpr(d - 1, env)} < sum{name} {vexpr(d - 1, env)} " \
                   f"then {vexpr(d - 1, env)} else {vexpr(d - 1, env)})"
        if env:   # inside `h0` itself: no recursive call
            return f"({vexpr(d - 1, env)} + {vexpr(d - 1, env)})"
        return f"(h0 {vexpr(d - 1, env)} {vexpr(d - 1, env)})"
    def scalar(v):
        if rng.random() < 0.7:
            return f"(sum{name} {v})"
        return f"(lane{name} {v} {idx() if rng.random() < 0.9 else rng.randint(-2, 6)})"
    step = rng.choice([n, n, 1, n + 1])
    length = rng.randint(0, 3 * n + 2)
    prog = [f"-- fuzz:simd\nh0 :: {name} -> {name} -> {name}\nh0 v w = {vexpr(2, ['v', 'w'])}\n",
            f"acc :: Array {elem} -> Int -> {name} -> {name}\n"
            f"acc a i s = if i + {n} <= lenArray a then acc a (i + {step}) "
            f"(s + load{name} a i) else s\n",
            f"fill :: Array {elem} -> Int -> Array {elem}\n"
            f"fill a i = if i < lenArray a then fill (setArray a i "
            f"({'toFloat ' if fl else ''}(i * 3 - 5))) (i + 1) else a\n",
            "main :: IO ()\nmain = do",
            f"  let a0 = fill (newArray {length} {lit()}) 0"]
    cur = "a0"
    for k in range(rng.randint(0, 3)):
        prog.append(f"  let a{k + 1} = store{name} {cur} {idx()} {vexpr(2, [])}")
        cur = f"a{k + 1}"
    for _ in range(rng.randint(1, 3)):
        prog.append(f"  putStrLn ({show} {scalar(vexpr(3, []))})")
    if rng.random() < 0.7:
        prog.append(f"  putStrLn ({show} {scalar(f'(load{name} {cur} {idx()})')})")
    prog.append(f"  putStrLn ({show} (sum{name} (acc {cur} {rng.randint(0, 2)} "
                f"(splat{name} {lit()}))))")
    return "\n".join(prog) + "\n"

def gen_total(rng):
    """Totality (axionc/src/total.rs): random counting loops (guards that may be off by one or
    point the wrong way, steps that may skip a bound or wrap at the largest Int), divisions
    behind random tests of the divisor, array accesses behind random guards, structural
    recursion with a missing clause or no progress — every function declared TOTAL, called with
    extreme arguments. The checker must refuse each one that can loop or abort: an accepted
    program must finish and return normally on every backend (a hang or a runtime error is a
    finding)."""
    big, small = "9223372036854775807", "(0 - 9223372036854775807)"
    funs, calls, names = [], [], []
    for k in range(1):   # one function: a refused one would refuse the whole program
        n = f"t{k}"
        kind = rng.randint(0, 3)
        if kind == 0:   # a counting loop
            cond = rng.choice(["i < n", "i <= n", "i > n", "i >= n", "i /= n", "n > i", "n - i > 0",
                               "i + 1 < n", "i < n - 1"])
            step = rng.choice(["i + 1", "i + 1", "i + 2", "i - 1", "i - 2", "i"])
            funs.append(f"{n} :: Int -> Int -> Int\n{n} i n = if {cond} then {n} ({step}) n else i\n")
            for a, b in rng.sample([("0", "5"), (f"({big} - 3)", big), (f"({small} + 3)", small),
                                    ("5", "0"), ("3", "3"), ("(0 - 4)", "7")], 3):
                calls.append(f"showInt ({n} {a} {b})")
        elif kind == 1:  # a division
            test = rng.choice(["b /= 0", "b > 0", "b >= 0", "b == 0", "b < 1", "not (b == 0)",
                               "b * b > 0", "b + 1 > 1"])
            then_div = rng.random() < 0.7
            op = rng.choice(["div", "mod"])
            body = (f"if {test} then a `{op}` b else 0" if then_div
                    else f"if {test} then 0 else a `{op}` b")
            funs.append(f"{n} :: Int -> Int -> Int\n{n} a b = {body}\n")
            for a, b in rng.sample([("7", "2"), ("7", "0"), (small, "(0 - 1)"), ("5", "(0 - 3)")], 3):
                calls.append(f"showInt ({n} {a} {b})")
        elif kind == 2:  # an array access
            test = rng.choice(["i < lenArray a", "i >= 0 && i < lenArray a", "i >= 0 && i <= lenArray a",
                               "0 <= i && i + 1 < lenArray a", "i > 0 && i < lenArray a",
                               "i >= 0 && i < lenArray a - 1"])
            idx = rng.choice(["i", "i", "i + 1", "i - 1"])
            funs.append(f"{n} :: Array Int -> Int -> Int\n{n} a i = if {test} then getArray a ({idx}) else 0 - 1\n")
            for i in rng.sample(["0", "3", "4", "(0 - 1)", big], 3):
                calls.append(f"showInt ({n} (newArray 4 9) {i})")
        else:            # structural recursion over a list
            nil = rng.random() < 0.85
            rec = rng.choice(["xs", "xs", "Cons x xs", "Cons 1 xs"])
            arms = ("  Nil -> 0\n" if nil else "") + f"  Cons x xs -> x + {n} ({rec})\n"
            funs.append(f"{n} :: List Int -> Int\n{n} l = case l of\n{arms}")
            calls.append(f"showInt ({n} [1, 2, 3])")
            calls.append(f"showInt ({n} Nil)")
        names.append(n)
    body = "\n".join(f"  putStrLn ({c})" for c in calls)
    return (f"-- fuzz:total\n{{-# TOTAL {' '.join(names)} #-}}\n" + "\n".join(funs)
            + f"\nmain :: IO ()\nmain = do\n{body}\n")

def gen(rng):
    r = rng.random()                    # distinct heap-resource surfaces
    if r < 0.08:
        return gen_sharing(rng)         # axmpv's shapes: shared-field updates, branch ownership
    r = (r - 0.08) / 0.92
    if r < 0.06:
        return gen_closure_values(rng)  # closures as values: owned, copied, stored, returned
    if r < 0.10:
        return gen_heap_array(rng)      # arrays of heap elements: copies in/out, frees
    if r < 0.15:
        return gen_nested_patterns(rng) # nested patterns → nested cases (match compilation)
    r = (r - 0.15) / 0.85               # the rest keep their relative weights
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
    if r < 0.95:
        return gen_builtins(rng)        # built-ins over heap args (the ownership table)
    if r < 0.985:
        return gen_ownership(rng)       # records, generic pass-through, borrowed returns
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

def _safe_by_construction(prog):
    """Generators whose every program is safe value-semantics code: a native AX0910/AX0911 on one is
    a reclamation GAP (hard finding), not a sound rejection — `gen_sharing`, `gen_closure_values`,
    `gen_nested_patterns`, `gen_local_fns`, `gen_tuple_acc`."""
    return ("fuzz:sharing" in prog or "fuzz:closures" in prog or "fuzz:nested" in prog
            or "fuzz:locals" in prog or "fuzz:tuples" in prog)

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
    if ("use-after-free" in err or "double-free" in err or "invalid pointer" in err
            or "heap-buffer-overflow" in err):
        return ("corruption", err[-600:])
    if "detected memory leaks" in err:
        # session tasks free what they own: a leak in a session-heap program is a real finding
        if "fuzz:session-heap" in src.read_text():
            return ("sessleak", err[-600:])
        # built-in programs reclaim everything: a leak means a wrong ownership entry
        if "fuzz:builtins" in src.read_text():
            return ("bileak", err[-600:])
        # safe-by-construction programs reclaim everything too: a leak is a reclamation gap
        if _safe_by_construction(src.read_text()):
            return ("safeleak", err[-600:])
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
    if "name not found at runtime" in (oi + ei) or "is native-only" in (oi + ei):
        rc, oc, ec = run([AXIONC, "--backend", "cranelift", str(src)])
        if rc == HANG_RC:
            return ("hang", f"cranelift exceeded {HANG_SECS}s:\n{prog[:500]}")
        if rc != 0:
            if _safe_by_construction(prog) and ("AX0910" in ec or "AX0911" in ec):
                return ("gap", ec[-600:])
            return ("ax0912", None) if "AX0912" in ec else ("verdict", f"native-only prog rejected:\n{ec[-400:]}")
        return asan_run(src, work, None)
    rc, oc, ec = run([AXIONC, "--backend", "cranelift", str(src)])
    if rc == HANG_RC:
        return ("hang", f"cranelift exceeded {HANG_SECS}s:\n{prog[:500]}")
    # verdict divergence
    if ri == 0 and rc != 0:
        if "AX0914" in ec:
            return ("ax0914", None)            # expected: a heap Array element, rejected natively
        if _safe_by_construction(prog) and ("AX0910" in ec or "AX0911" in ec):
            # every sharing / closure-value program is safe value-semantics code: a refusal is a
            # reclamation gap in Auto-Drop (the classes axmpv kept hitting), not a sound rejection
            return ("gap", ec[-600:])
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
            return ("ax0910", ec[-1500:])
        return ("verdict", f"interp ran but cranelift rejected:\n{ec[-400:]}")
    if ri != 0 and rc == 0:
        return ("verdict", f"cranelift ran but interp rejected:\n{ei[-400:]}")
    if "fuzz:total" in prog and ri != 0 and "error[" not in (oi + ei):
        # every function is declared total and was accepted: it must not abort
        return ("totality", f"an accepted total function failed at run time:\n{(oi + ei)[-400:]}")
    if ri != 0 and rc != 0:
        if "fuzz:locals" in prog:              # every local-function program is well-typed + linear
            return ("gap", f"front end rejected a generated program:\n{(oi + ei)[-600:]}")
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
    ap.add_argument("--only", metavar="NAME",
                    help="use only the generator gen_NAME (e.g. closure_values, heap_array)")
    ap.add_argument("--save-refusals", metavar="DIR",
                    help="also save each sound AX0910 refusal (program + error) to DIR, for triage")
    ap.add_argument("--max-refusals", type=int, metavar="N",
                    help="fail when more than N programs are refused natively (AX0910): the "
                         "generators' shapes are all compiled today, so a new refusal is a "
                         "regression in what native code accepts (nightly runs with 0)")
    a = ap.parse_args()
    generate = globals()[f"gen_{a.only}"] if a.only else gen
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
            prog = generate(rng)
            verdict, detail = check(prog, work)
            tally[verdict] = tally.get(verdict, 0) + 1
            if verdict in ("corruption", "divergence", "verdict", "hang", "sessleak", "bileak",
                           "biax0910", "gap", "safeleak"):
                hard += 1
                FAILDIR.mkdir(exist_ok=True)
                f = FAILDIR / f"seed{a.seed}_i{i}_{verdict}.axi"
                f.write_text(prog)
                print(f"\n[{verdict.upper()}] i={i} saved {f}\n{detail}\n")
                if not a.keep_going:
                    break
            elif verdict == "ax0910" and a.save_refusals:
                d = pathlib.Path(a.save_refusals)
                d.mkdir(parents=True, exist_ok=True)
                (d / f"seed{a.seed}_i{i}.axi").write_text(prog)
                (d / f"seed{a.seed}_i{i}.err").write_text(detail or "")
            if verdict not in ("corruption", "divergence", "verdict", "hang", "sessleak", "bileak",
                               "biax0910", "gap", "safeleak") and i % 25 == 0:
                print(f"  {i}/{a.count} … {dict(tally)}")
    print(f"\nsummary (seed {a.seed}): {dict(tally)}")
    if hard:
        print(f"FAIL: {hard} hard finding(s) — repros in {FAILDIR}/")
        return 1
    refused = tally.get("ax0910", 0)
    if a.max_refusals is not None and refused > a.max_refusals:
        where = f" — programs in {a.save_refusals}/" if a.save_refusals else ""
        print(f"FAIL: {refused} native refusal(s) (AX0910), more than --max-refusals "
              f"{a.max_refusals}{where}")
        return 1
    print("OK: no corruption / divergence / verdict-mismatch")
    return 0

if __name__ == "__main__":
    sys.exit(main())
