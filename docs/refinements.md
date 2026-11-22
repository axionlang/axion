# Integer refinements

A refinement states a fact about an `Int` in a function's signature, and the compiler proves it
at every call. Facts it proves about an array index also remove that access's bounds check.

```haskell
get :: a:Array Int -> {i:Int | 0 <= i && i < len a} -> Int
get a i = getArray a i            -- no bounds check: the signature proves the index

sumFrom :: a:Array Int -> {i:Int | 0 <= i} -> Int -> Int
sumFrom a i acc = if i < lenArray a then sumFrom a (i + 1) (acc + get a i) else acc
```

`sumFrom` compiles because each call is proven where it is made: `get a i` from `0 <= i`
(its own refinement) and `i < lenArray a` (the `if`), and the recursive call's `0 <= i + 1`
from `0 <= i`. A call that cannot be proven is an error (**AX0600**):

```
error[AX0600]: cannot prove `0 <= i && i < (len a)` for the argument `i` of `get`
  |
5 | bad a k = get a k
  |                 ^ must satisfy `0 <= i && i < (len a)`
  = help: known here: 0 <= len a
```

## Syntax

In a top-level signature, a parameter or the result can be written

- `x:T` — names the parameter, so a refinement can mention it (`a:Array Int`);
- `{x:Int | p}` — names it and refines it with the predicate `p`.

A predicate compares `Int` expressions with `< <= > >= == /=`, joins comparisons with `&&` and
`||`, and may use integer literals, `+ - *`, the signature's `Int` names, and `len a` for an
array parameter `a`. A result refinement may also mention the result's own name:

```haskell
clamp :: Int -> {hi:Int | 0 <= hi} -> {r:Int | 0 <= r && r <= hi}
```

Refinements are only allowed on top-level functions. A refined function must be called with
all the arguments its refinements mention (**AX0602**): in `map idx xs` the arguments are not
known where `idx` is named, so nothing can be proven. A refinement outside this language is
**AX0601**.

## What a call can use

The checker proves a call from what is known at that point:

- the enclosing function's own refinements;
- the conditions of the `if`s and guards on the path to the call (`if i < lenArray a then …`,
  the negation of earlier guards), and `&&`/`||` short-circuit facts;
- `let` bindings of `Int` expressions, and an `Int` literal matched by a `case`;
- a refined result of a call (`get a (clamp k (lenArray a - 1))`);
- array lengths: `lenArray a`, `len (setArray a i v) = len a`, and `newArray n x` has length
  `n` when `n >= 0` is known (a negative length gives an empty array);
- division and remainder by a positive constant of a value known to be non-negative.

Only comparisons whose sides are evidently `Int` count: a `Float` comparison is never read as an
integer fact. Products of two unknowns, other function results, and anything else are treated as
unknown values, which can only make a proof fail.

## Overflow

`Int` is a 64-bit machine integer that wraps. Inside a predicate, arithmetic is exact
(mathematical). In code, `i + 1` counts as the integer `i + 1` only when the checker proves it
does not overflow; otherwise it is an unknown value. So

```haskell
wraps k = if k >= 0 then next (k + 1) else 0     -- AX0600: k + 1 wraps when k is the largest Int
```

is refused, while `i + 1` with `i < lenArray a` is fine: array lengths are below 2^61 (an array
whose size does not fit memory is never created).

## What is guaranteed

Refinements are checked on every backend (the interpreter too) and are erased afterwards; a
program runs exactly as without them. The checker decides linear integer arithmetic by
Fourier–Motzkin elimination (exact over the rationals, tightened for integers); when a search
grows too large it gives up and the call is refused. An array access whose index it proves in
bounds is compiled without its check — `getArray`/`setArray` in any function, refined or not.

Every proof carries a **certificate**: the steps of the refutation (non-negative combinations of
the facts and the negated goal, and gcd tightenings) ending in `0 >= k` with `k < 0`. A proof
counts only when a separate, small checker (`refine::check_cert`) replays it. That checker is the
algorithm of `metatheory/AxionRefine.lean`, whose theorem `sound` proves in Lean that an
accepted certificate means the facts and the negated goal have no integer solution; and
`metatheory/refine-trace.sh` re-checks every certificate the compiler produces over the corpus
with the Lean `check` itself (in CI, as part of `bridge.sh`). So the arithmetic is not trusted.

What remains trusted is reading the facts and the goal off the program: which comparisons count,
overflow, array lengths, the meaning of `newArray`/`setArray`/`div`. That part is exercised by
`scripts/fuzz.py --only refine` (random, often subtly wrong guards: every accepted program must
agree with the interpreter, which always checks, and be ASan-clean).

Fixtures: `tests/fixtures/refinements.axi`, `refine_reject.axi`, `refine_malformed.axi`.
