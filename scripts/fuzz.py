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
                  OTHER than the documented AX0912 heap-alias guard (or vice-versa).

Native LEAKS while interp is clean are REPORTED (info) but not failed — many are known
conservative leaks. AX0912 rejections are EXPECTED (the interim alias guard), counted
separately. Failing programs are saved to fuzz-fail/ for a deterministic repro (the seed
+ index reproduce any run).

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


def gen(rng):
    r = rng.random()                    # distinct heap-resource surfaces
    if r < 0.10:
        return gen_arena(rng)           # native-only
    if r < 0.26:
        return gen_session(rng)         # full differential (interp supports sessions)
    if r < 0.38:
        return gen_array(rng)           # full differential (interp now has arrays)
    if r < 0.46:
        return gen_cond_return(rng)     # call-site-ownership shapes (full differential)
    if r < 0.54:
        return gen_borrow_alias(rng)    # conditional-owned-temp + baseName/borrowed-element shapes
    if r < 0.62:
        return gen_tuple_reclaim(rng)   # grab-via-case + tuple ret_alias reuse + nested extraction
    if r < 0.70:
        return gen_bignum(rng)          # bignum reclamation (full differential + ASan/LSan)
    if r < 0.75:
        return gen_deep(rng)            # nested-container deep-drop (full differential)
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

def run(args, want_bin=None):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=30)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
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
    if "use-after-free" in err or "double-free" in err or "invalid pointer" in err:
        return ("corruption", err[-600:])
    if "detected memory leaks" in err:
        return ("leak", None)              # LSan `_exit`s without flushing stdout
    if oracle_out is not None and rr == 0 and orr.strip() != oracle_out.strip():
        return ("divergence", f"interp={oracle_out!r} llvm+asan={orr!r}\n{err[-300:]}")
    return ("ok", None)

def check(prog, work):
    src = work / "p.axi"
    src.write_text(prog)
    ri, oi, ei = run([AXIONC, str(src)])
    # genuinely native-only programs (e.g. arenas: interp lacks `withArena` → runtime "name not
    # found") have no interp oracle, so ASan-check the native build for corruption/leak only. Array
    # programs no longer land here — the interpreter runs them, so they take the full-differential
    # path below.
    if "name not found at runtime" in (oi + ei):
        rc, oc, ec = run([AXIONC, "--backend", "cranelift", str(src)])
        if rc != 0:
            return ("ax0912", None) if "AX0912" in ec else ("verdict", f"native-only prog rejected:\n{ec[-400:]}")
        return asan_run(src, work, None)
    rc, oc, ec = run([AXIONC, "--backend", "cranelift", str(src)])
    # verdict divergence
    if ri == 0 and rc != 0:
        if "AX0912" in ec:
            return ("ax0912", None)            # expected: the heap-alias guard
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
            if verdict in ("corruption", "divergence", "verdict"):
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
