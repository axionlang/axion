# Totality

A function declared **total** is proven to return a value for every argument: it terminates,
and nothing on any path can abort. Declare it with a pragma naming one or more top-level
functions:

```haskell
{-# TOTAL sumTo len #-}
sumTo :: Int -> Int
sumTo n = go 0 1
  where go acc i = if i >= n then acc + i else go (acc + i) (i + 1)

len :: List a -> Int
len xs = case xs of
  Nil -> 0
  Cons _ rest -> 1 + len rest
```

A function that is not total is an error (`AX0700`–`AX0702`) that says why. Totality is
opt-in and changes nothing at run time. Programs without the pragma are not checked.

## Termination

Every recursive call (including mutual recursion, and recursion through `where`/`let` local
functions) must make something smaller, by the size-change principle: on every possible cycle
of calls, some measure strictly decreases infinitely often and never grows. Each argument
position offers these measures:

- **structure:** a value a pattern took apart (`rest` from `Cons _ rest`) is smaller than the
  value it came from; passing a parameter on unchanged (or rebuilt from its own pattern) keeps
  its size.
- **an `Int` counting down:** `n` in `f (n - 1)`, where `n >= 0` is known at the call.
- **an `Int` counting up to a bound:** `b - i` for another `Int` parameter or captured value
  `b`, `lenArray a - i`, or `strLen s - i`, as in `if i < n then go (i + 1) n`.

What is known at a call is what refinements know there: the `if`/guard conditions on the path,
`let`s, the function's own refinements ([refinements.md](refinements.md)). The arithmetic is
proven by the same Fourier–Motzkin procedure, and each proof's certificate is replayed by
`refine::check_cert`, the checker `metatheory/AxionRefine.lean` proves sound.

Lexicographic orders are found without help:

```haskell
ack :: Int -> Int -> Int
ack m n
  | m <= 0 = n + 1
  | n <= 0 = ack (m - 1) 1
  | otherwise = ack (m - 1) (ack m (n - 1))
```

`Int` is a machine integer, and this matters:

```haskell
upTo i n = if i <= n then upTo (i + 1) n else i   -- AX0700
```

is refused, correctly: when `n` is the largest `Int`, `i + 1` wraps around and the loop never
ends. `if i < n` (or `i >= n` for the exit) is accepted. A `Float` counter is never a measure
(`x +. 1.0` can stop changing `x`).

## No aborts

A total function must also return normally on every path:

- **patterns.** Every `case`, clause list and lambda pattern covers every value, nested patterns
  included (`Cons (Just x) _` alone does not cover `Cons Nothing _`).
- **guards.** Guards cannot all fail: the last is `otherwise`, or the earlier ones provably
  cover every value. Note that `x > 0.0 | x <= 0.0` does not (NaN).
- **array accesses** (`getArray`, `setArray`) and **SIMD** lanes, loads and stores must be
  proven in range, e.g. `if i >= 0 && i < lenArray a then getArray a i else 0`.
- **divisions** (`div`, `mod`, an `Int` `/`) need a divisor proven non-zero:
  `if b == 0 then 0 else a `div` b`. An `Integer` division needs a non-zero literal divisor.
- **built-ins.** Only built-ins that always return are allowed. `exitWith` (and so `die`) and FFI
  calls are not.

`Float` arithmetic, `Int` wrap-around, I/O and channel operations are total.

## Callees

Everything a total function uses must be total too: its own functions, the prelude's, and
instance methods. They are checked the same way, so a total function can use `map`, `foldl`,
`filter`, `length`, `++`, `head` (which returns a `Maybe`) and derived `show`/`==`. A function
passed as an argument is checked where it is written: a lambda as part of its enclosing
function, a named function as a callee. A function used as a value inside its own recursion
(`f n = apply f (n - 1)`) cannot be followed and is refused.

## What is guaranteed, and what is trusted

Totality is a static check over the program before code generation, so every backend runs the
same proven program.

Not trusted:
- **the size-change decision.** Each accepted recursive group emits a certificate (its call
  graphs and the closure `total.rs` computed; `axionc --emit sct-certs`), and
  `metatheory/sct-trace.sh` re-checks every one over the corpus with Lean. `AxionSct.lean`
  proves what an accepted certificate means: the closure holds the composite of every chain of
  calls, and every idempotent self-graph in it has a strict self-edge. That this implies
  termination is the size-change theorem (Lee, Jones and Ben-Amram, POPL 2001), cited, not
  proven in Lean.
- **the arithmetic of each decrease and non-zero/in-range proof:** certificates, replayed by
  `refine.rs`'s checker (not yet in the Lean trace).

Trusted: the pattern-coverage check (`axionc/src/total.rs`), and reading the size-change graphs
and facts off the program (shared with refinements).
Exercised by `scripts/fuzz.py --only total`, which generates loops with off-by-one guards,
wrong-way steps, wrapping bounds, unguarded divisions and accesses. Every accepted program must
finish and return normally on every backend.

Error codes: **AX0700** (may not terminate), **AX0701** (may fail at run time), **AX0702**
(calls a function that is not total), **AX0703** (unknown name in the pragma).

Fixtures: `tests/fixtures/total.axi`, `total_reject.axi`.
