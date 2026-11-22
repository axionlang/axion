# Contracts

A contract states what a function needs from its caller and what it promises in return:

```haskell
{-# CONTRACT withdraw
      requires 0 <= amount && amount <= balance
      ensures 0 <= result && result <= balance #-}
withdraw :: Int -> Int -> Int
withdraw balance amount = balance - amount
```

The compiler proves each obligation where it can, and checks it at run time where it cannot:

- a **`requires`** is proven at each call, from what is known there (the same facts as for
  [refinements](refinements.md): `if` and guard conditions, `let`s, the caller's own contract,
  array lengths). A call where it is proven costs nothing. A call where it is not gets a check
  just before it.
- an **`ensures`** is proven over the function's body, assuming its `requires`. If it is proven,
  callers know it after every call, for free. If not, each call from outside the function checks
  the result after the call.

A failed check stops the program, like a failed bounds check:

```
axion: contract violated: `withdraw` requires `0 <= amount && amount <= balance` (balance = 10, amount = 13), called from `main`
```

Inside the function, the `requires` are facts: `{-# CONTRACT at requires 0 <= i && i < len a #-}`
on `at a i = getArray a i` removes that access's bounds check, because every call to `at` has
either proven the index or checked it.

## Which obligations are proven

`axionc --emit contracts file.axi` lists every obligation and how it is discharged:

```
9:27  `withdraw` ensures `0 <= result && result <= balance`  proven
51:22  `withdraw` requires `0 <= amount && amount <= balance`  proven
54:22  `at` requires `0 <= i && i < (len a)`  checked at run time
57:33  `withdraw` used as a value (its whole contract)  checked at run time
15 obligation(s): 9 proven, 6 checked at run time
```

A `--certified` build prints the obligations that stay checked at run time, with the totals.

## Syntax

```haskell
{-# CONTRACT f requires P ensures Q … #-}
```

`f` is a top-level function of the module with a type signature. There can be any number of
`requires` and `ensures` clauses, in any order, over one or more lines. A function has at most
one contract.

The predicates are those of refinements: comparisons of `Int` expressions (`< <= > >= == /=`)
joined by `&&` and `||`, with integer literals, `+ - *`, the function's `Int` parameters, and
`len a` for an `Array` parameter `a`. Parameters are named by the function's first clause
(`withdraw balance amount = …`) or its signature (`a:Array Int`). An `ensures` also names the
result `result`. A predicate outside this language is **AX0601**; a malformed contract (no
`requires`/`ensures`, a predicate that does not parse, a function that is not top-level or has no
signature, a second contract) is **AX0603**.

A contract and signature refinements can be combined. A refinement must be proven at every
call (**AX0600** otherwise), while a contract falls back to a run-time check.

## How the checks are placed

- **A call where a `requires` is not proven:** the arguments the predicate mentions are
  evaluated once (a variable is used as it is), the predicate is tested, and then the call is
  made with those values.
- **An `ensures` not proven:** the result of each call from outside the function is bound and
  tested. Calls from inside the function's own body are not checked, so a loop stays a loop (a
  tail call stays a tail call). The compiler then does not assume the `ensures` after those
  inner calls: it re-checks the body without them, so nothing relies on an unchecked promise.
- **The function used as a value**, maybe partly applied (`map (withdraw 50) xs`): it becomes a
  lambda that checks the whole contract at each call.

What a `requires` makes known inside the function is sound because every way of calling it
(proven call, checked call, value) establishes it first.

## With totality and parallel loops

A [total](totality.md) function may call a contract function when the `requires` are proven at
that call, and inside a contract function they are facts (`requires d /= 0` makes `x `div` d`
total). A check left for run time can fail, so a total function cannot contain one:

```
error[AX0701]: `f` is declared total, but the contract `safeDiv` requires `d /= 0` is not proven here, so it is checked at run time
```

A contract check is not an effect: a [`parFor`](parallel.md) kernel may call contract functions.
Inside a kernel `\i x -> …`, `0 <= i && i < len a` is known for the array `a` the loop runs
over, so contracts and accesses at `i` are usually proven there.

## What is trusted

The proofs are those of refinements, each with a certificate replayed by the checker that
`metatheory/AxionRefine.lean` proves sound. Trusted: the reading of facts off the program
(shared with refinements), and the placement of the checks (`axionc/src/contracts.rs`).

Fixtures: `tests/fixtures/contracts.axi`, `contracts_fail.axi`, `contracts_reject.axi`.
