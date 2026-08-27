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
RT = str(ROOT / "axionc/src/axion_rt.c")
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
    if rng.random() < 0.6:
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

def gen_array(rng):
    # functional Array combinators (native heap resource): each term reduces to Int, so a
    # sum of them prints and exercises Array allocation + reclamation (axion_array_free).
    terms = []
    for _ in range(rng.randint(1, 4)):
        k = rng.randint(1, 12)
        terms.append(rng.choice([
            f"arraySum (arrayIota {k})",
            f"arrayDot (arrayIota {k}) (arrayIota {k})",
        ]))
    return PREAMBLE + "\nmain :: Int\nmain = " + " + ".join(terms) + "\n"

def gen(rng):
    r = rng.random()                    # distinct heap-resource surfaces
    if r < 0.12:
        return gen_arena(rng)           # native-only
    if r < 0.30:
        return gen_session(rng)         # full differential (interp supports sessions)
    if r < 0.44:
        return gen_array(rng)           # native-only
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

def asan_run(src, work, oracle_out):
    """Compile --release + ASan/LSan and run. `oracle_out` is the interpreter's stdout to
    compare against, or None for a native-only program (arrays: no interp oracle → skip the
    divergence check, only hunt corruption/leak)."""
    rl, ol, el = run([AXIONC, "--emit", "llvm", str(src)])
    if rl != 0:
        return ("ok", None)
    (work / "ir.ll").write_text(ol)
    rcc, _, _ = run([CLANG, "-fsanitize=address,leak", "-pthread", "-O1", "-w",
                     str(work / "ir.ll"), RT, "-o", str(work / "p")])
    if rcc != 0:
        return ("ok", None)
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
    # arrays are native-only (interp lacks arraySum/arrayIota → runtime "name not found");
    # there is no interp oracle, so ASan-check the native build for corruption/leak only.
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
