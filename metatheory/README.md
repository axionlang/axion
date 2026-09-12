# Metatheory — machine-checked soundness of the drop-verifier (Track 2)

Axión's memory-safety story rests on the **drop-balance verifier** (`axionc/src/verify.rs`), the
compile-time oracle that proves the final drop-inserted Core never double-frees, never uses after
free, and never leaks (the AX0910 / AX0911 hard gates). **Track 1** proved the verifier *catches*
the known bug classes as findings. **Track 2** — this directory — turns the verifier's own
judgment into a **machine-checked theorem** in Lean 4:

> If the judgment accepts a program, its execution cannot double-free, cannot use-after-free, and
> cannot leak.

## What is proved

`AxionDrop.lean` (dependency-free — stock Lean 4, no Mathlib) mechanizes the straight-line core of
the verifier — the ANF let-sequence of resource operations that `verify.rs` abstractly interprets:

| Theorem | Statement | Verifier correspondence |
|---|---|---|
| `step_sound` | every accepted step is a runtime step, preserving the owned↔live coupling | the per-op `Verifier::term` transition |
| `run_check` | acceptance of a whole sequence ⟹ the runtime runs it to completion | the fold over a function body |
| `no_corruption` | accepted ⟹ execution never gets stuck (no double-free / UAF / faulting use) | the AX0910 corruption gate |
| `no_leak` | accepted ⟹ the final heap has **no live cell left** | the AX0911 leak gate (`leak_check` at exit) |
| `sound` | accepted ⟹ memory-safe **and** leak-free, together | the combined guarantee |

The proof hinges on one invariant, `Inv o h : ∀ n, o n = true ↔ h n = live` — the abstract
owned-set is *exactly* the set of live heap cells. It holds initially and is preserved by every
accepted step, so an accepted program can never reach a faulting state.

Non-vacuity is checked too (mirroring `verify.rs`'s buggy-Core unit tests): a double-free, a
use-after-free, and a leak are each shown to be **rejected**, and a balanced program **accepted** —
so the theorem is not vacuously true.

## Model correspondence

- `Status` (`fresh → live → freed`) and `Heap` — the runtime a `drop` acts on.
- `Owned` — the `owned` bit of `Val` tracked per variable in `Verifier`.
- `Op.alloc / use / drop` — a producer (`MakeCon`/fresh `RtCall`), a borrow/read (`use_atom`), and
  `do_drop`.
- `stepRun` gets stuck exactly on a memory fault; `stepChk` is the verifier's accept/reject step;
  `accepts` couples "runs to completion" with "final owned-set empty" (leak-free at exit).

The single-path model is faithful because the verifier checks each control-flow path independently
and joins branches with `merge_vals`; the per-path guarantee proved here is what each branch must
satisfy.

## Running the gate

```sh
./metatheory/check.sh
```

Exit 0 means every theorem type-checks, no proof uses `sorry`, and `sound` depends only on Lean's
standard axioms (`propext`, `Quot.sound`). Lean 4 is provisioned on demand via `nix shell
nixpkgs#lean4` — no global install required.

## Scope & next slices

This slice covers the straight-line linear core — the exact shape of double-free / UAF / leak the
verifier tracks with `Val.owned` + the exit leak-check. Natural extensions, each a further Track-2
increment: **branch join** (model `if`/`case` + `merge_vals` and prove the join preserves `Inv` on
both arms); **interior aliases** (the `borrows` set + `borrow_return_summary`, i.e. the `grab`
field-alias class); and **drop keys** (the `WrongDropKey` cross-check). Each builds on `Inv` and the
`step_sound` skeleton here.
