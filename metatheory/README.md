# Metatheory — machine-checked soundness of the drop-verifier (Track 2)

Axión's memory-safety story rests on the **drop-balance verifier** (`axionc/src/verify.rs`), the
compile-time oracle that proves the final drop-inserted Core never double-frees, never uses after
free, and never leaks (the AX0910 / AX0911 hard gates). **Track 1** proved the verifier *catches*
the known bug classes as findings. **Track 2** — this directory — turns the verifier's own
judgment into a **machine-checked theorem** in Lean 4:

> If the judgment accepts a program, its execution cannot double-free, cannot use-after-free, and
> cannot leak.

## What is proved

`AxionDrop.lean` (dependency-free — stock Lean 4, no Mathlib) mechanizes the verifier's judgment
over a **tree-structured Core with branches** (`if`/`case`) — the straight-line ANF let-sequence is
the branch-free fragment. Because branching is nondeterministic, the proof is the textbook
**progress + preservation** over a small-step machine, so it quantifies over *every* branch path:

| Theorem | Statement | Verifier correspondence |
|---|---|---|
| `step_sound` | every accepted op is a runtime op, preserving the owned↔live coupling | the per-op `Verifier::term` transition |
| `chk_seq` | the judgment composes over `seq` (arm + continuation) | how a branch arm flows into the join continuation |
| `preservation` | a step out of a well-typed state lands well-typed | — |
| `progress` | a well-typed state is `done` or can step (never stuck) | — |
| `no_corruption` | accepted ⟹ **no reachable state is stuck** (no double-free / UAF / fault), on any path | the AX0910 corruption gate |
| `no_leak` | accepted ⟹ any finished path's heap has **no live cell left** | the AX0911 leak gate (`leak_check` at exit) |
| `sound` | accepted ⟹ memory-safe **and** leak-free, on every path | the combined guarantee |

The proof hinges on one invariant, `Inv o h : ∀ n, o n = true ↔ h n = live` — the abstract
owned-set is *exactly* the set of live heap cells. It holds initially and is preserved by every
accepted step, so no reachable state ever faults.

**The branch join** (`Chk.brn`) is the heart of this slice: it requires **both arms to reach the
same owned-set `om`** before the continuation. That is the sound core of `verify.rs`'s
`merge_vals` — the merged abstract state can stand for *both* runtime heaps only when the arms leave
the same owned-set. An imbalance is exactly the conditional-param-return alias class V-1 catches,
and R-5's container deep-copy is what makes both arms of a real container branch balance.

Non-vacuity is checked too (mirroring `verify.rs`'s buggy-Core unit tests), by **dogfooding the
theorems**: a double-free and a use-after-free are rejected because they fault on a path
(contrapositive of `no_corruption`); an **unbalanced branch** is rejected because its else-arm
finishes with a live cell (contrapositive of `no_leak`); and a balanced branching program is
accepted — so the theorems have real bite.

## Model correspondence

- `Status` (`fresh → live → freed`) and `Heap` — the runtime a `drop` acts on.
- `Owned` — the `owned` bit of `Val` tracked per variable in `Verifier`.
- `Op.alloc / use / drop` — a producer (`MakeCon`/fresh `RtCall`), a borrow/read (`use_atom`), and
  `do_drop`.
- `Expr.op / brn / done` and `seq` — the ANF sequence, the two-armed branch (+ continuation), the
  tail, and arm-then-continuation grafting.
- `stepRun` gets stuck exactly on a memory fault; `Step` is the small-step machine (nondeterministic
  at `brn`); `stepChk`/`Chk` are the verifier's accept/reject transition and its lift to `Expr`;
  `accepts` couples "checks" with "final owned-set empty" (leak-free at exit).

## Running the gate

```sh
./metatheory/check.sh
```

Exit 0 means every theorem type-checks, no proof uses `sorry`, and `sound` depends only on Lean's
standard axioms (`propext`, `Quot.sound`). Lean 4 is provisioned on demand via `nix shell
nixpkgs#lean4` — no global install required.

## Interior aliases — `AxionAlias.lean`

The second file extends the story to the piece the whole R-1…R-5 / V-1 arc was actually about:
`verify.rs`'s `borrows` set + `borrow_return_summary`. A value is now an OWNER or a **borrow** —
an interior pointer into another owner's allocation (`Cell.bref t`; the `grab w = inner w` shape).
The machine faults on the two hazards borrows add, and the checker rejects them:

| Theorem | Statement |
|---|---|
| `no_corruption` / `no_leak` / `sound` | same guarantees, now over owner/borrow states, on every path |
| `drop_of_alias_rejected` | dropping a borrow (freeing the owner through an interior pointer) can't be accepted — the `grab` double-free class (`DropOfAlias`) |
| `dangling_use_rejected` | using a borrow after its owner is freed can't be accepted (`UseAfterFree`) |
| `v1_conditional_alias_return_rejected` | `if _ then (r := borrow w) else (r := fresh owner); drop r; drop w` is **rejected** — the arms can't balance (one leaves `r` a borrow, the other an owner). This is exactly the V-1 conditional-param-return alias. |
| `v1_copy_fixed_accepted` | replacing the borrow arm with a **`copy`** (R-5's `axion_copy_T`, a fresh owner) makes the arms balance, so the same branch is **accepted** — the mechanized statement that the deep-copy is what admits a real conditional container return |
| `safe_borrow_accepted` | a borrow used safely then its owner freed IS accepted — borrows aren't over-rejected |

Once interior aliases and ABA-safety are in play the abstraction becomes exact (the checker tracks
the same owner/borrow/freed structure as the heap), so the content lands entirely on the **branch
join**: the static check inspects both arms and requires them to agree, while a run takes one — the
`Chk.brn`-must-balance rule is `merge_vals`, and it is precisely what rejects V-1 and what a `copy`
repairs. `Op.borrow` models the unsafe interior alias, `Op.copy` models `axion_copy_T`.

## Drop keys — `AxionKey.lean`

The third file adds `verify.rs`'s `WrongDropKey` cross-check: `do_drop` verifies that a
`Drop(v, key)`'s reclaimer matches `v`'s type (an `Integer` freed by `axion_bignum_free`, a
`List$Int` by `axion_drop_List$Int`, …). Freeing with the wrong key is a bad-free — the class
behind the multi-param mis-key bug V-2 catches. Cells carry a **type** (`Cell.live ty`), drops
carry the reclaimer **key** (`Op.drop n key`), and the machine faults on a key/type mismatch.

| Theorem | Statement |
|---|---|
| `no_corruption` / `no_leak` / `sound` | the guarantees, now over typed cells, on every path |
| `no_bad_free` | whenever an accepted program reaches a `drop n key`, the cell is live and `key` is exactly its type — the reclaimer always matches (`WrongDropKey`) |
| `wrong_key_drop_rejected` | dropping a `ty0` value with a `ty1` key can't be accepted (bad-free) |
| `correct_key_accepted` | a correctly-keyed drop is accepted |
| `heterogeneous_branch_drop_rejected` | a value that is `ty0` on one arm and `ty1` on the other has no single correct reclaimer, so any drop of it after the join is rejected — the `merge_vals` reconciliation of `Val.key` |

## Faithfulness bridge — `bridge.md`

The proofs above establish only that the *model* is sound. The **bridge** (`metatheory/bridge.md`,
`axionc/tests/bridge.rs`, run via `metatheory/bridge.sh`) ties the model to the code: for each
canonical shape it asserts the **real verifier's verdict** on a real `.axi` program equals the
verdict the **corresponding Lean theorem proves** (and, for rejects, the corruption *kind* too).
The unsafe shapes are produced with the same default-off hooks Track 1 used (`AXION_NO_ALIAS_COPY`,
`AXION_NAIVE_ELEM_KEY`), so the verifier analyses exactly the Core the model's unsafe rules
abstract. `bridge.sh` runs both halves — the Lean proofs (`check.sh`) and the verifier agreement
(`cargo test --test bridge`) — linked by the per-row `lean_theorem` field. See `bridge.md` for the
correspondence table and the honest scope notes (it is a curated per-shape pairing, not a
whole-corpus auto-translation; that heavier `--emit model-trace` widening is the noted follow-up).

## Move / escape — `AxionMove.lean`

The other slices can only lose ownership by `drop` (freeing). Real Core loses ownership far more
often by a **move/escape**: a value handed into a constructor, passed to a `%1` (consuming) call, or
*returned* to the caller — transferred, not freed, so not a leak. `AxionMove.lean` adds `Op.moveOut`
(→ `Cell.moved`) and re-proves soundness with it:

| Theorem | Statement |
|---|---|
| `no_corruption` / `no_leak` / `sound` | the guarantees, with moves, on every path |
| `escape_is_leak_free_accepted` | `alloc; moveOut` (transfer out instead of freeing) is **accepted** — a moved-out value is reclaimed elsewhere, not a leak (the case plain `AxionDrop` would wrongly reject) |
| `use_after_move_rejected` / `drop_after_move_rejected` | using or dropping a value after it's moved out faults |
| `forgotten_owner_is_leak_rejected` | a value neither dropped nor moved out is still a leak — moves don't weaken leak-freedom |

This is the foundational step toward a whole-corpus `--emit model-trace` bridge: without an
escape/move op the model can't describe most corpus functions (which return or embed owned values),
which is why the current bridge is a curated per-shape pairing. `moveOut` ↔ a value leaving Δ in
`verify.rs` (`DeltaEffect.moves` / `.alias`).

## Concurrency: deadlock-freedom — `AxionSession.lean`

The other files mechanize the *memory-safety* verifier. This one opens the *concurrency* half — the
Axión Session Calculus (`docs/phase-3-calculus.md`). The session runtime is implemented and runs
(the `session_run_*` fixtures: bound/spawn/send/recv/offer/cancel over the M:N scheduler, leak-free),
and the frontend enforces the calculus's structural invariants — `AX0302` (an endpoint can't escape
its `bound` nursery — confinement) and `AX0305` (`spawn` only makes a parent↔child edge — a forest)
— so the communication graph is acyclic by construction. But the calculus's §6 metatheory (T1–T5)
was a stated contract, unmechanized. This slice discharges the reachable, graph-structural rung —
**T2 Progress + T4 Deadlock-freedom** — in stock Lean (§6 defers the separation-logic T1/T3/T5 to
Iris/Actris "medium term"):

| Theorem | Statement |
|---|---|
| `progress` | an acyclic configuration with any active thread always has a **runnable** one (the minimal-rank thread can't be blocked) — T2 |
| `no_deadlock` | no acyclic configuration is ever deadlocked (all-blocked-with-work) — T4 |
| `spawn_preserves_acyclic` | forking a fresh higher-ranked child blocked on an existing thread keeps the graph acyclic — deadlock-freedom **by construction**, the invariant `AX0302`/`AX0305` maintain (needs no axioms) |
| `two_cycle_has_no_rank` + a raw 2-cycle example | acyclicity is **essential**: a cycle admits no rank witness (can't be a `Config`) and genuinely deadlocks — so the guarantee rests on the confinement/forest checks |

Acyclicity is witnessed by a `rank` (a topological order of the cut-tree — the depth `spawn`
assigns). This is the calculus's claim "deadlock-freedom is a corollary of acyclicity / cut
elimination," mechanized. Later rungs on the same foundation: **T3 session fidelity** (protocol
adherence over the reduction) and **T5 cancellation safety**.

## Scope & remaining work

Covered: the linear core; branches (`merge_vals` arm-balance, all paths); interior aliases
(borrows, drop-of-alias, dangling use, the V-1 ↔ R-5-copy pair); drop keys (`WrongDropKey`,
including the heterogeneous-branch case); moves/escape (`moveOut`, escape-is-not-a-leak); and a
faithfulness bridge tying the model's verdicts to the real verifier on the canonical shapes.

The remaining piece for a **whole-corpus** `--emit model-trace` bridge (beyond the curated one) is
the translator plus two more model features it needs: **param-ownership** (a function's parameters
enter as owned/borrowed, not from `sInit`) and **call effects** (summarizing a callee's move/borrow
of its args). With `moveOut` now in hand, `alloc`/`moveOut`/`drop`/`use`/`borrow`/`copy` cover the
per-op vocabulary; params + call-summaries are the remaining modelling work before Core → `Expr`
translation is faithful across the corpus.
