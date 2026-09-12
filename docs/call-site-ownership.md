# Design plan — call-site ownership & reuse analysis (region-lite)

**Status:** DESIGN (not yet implemented). This plan supersedes the piecemeal
copy-normalization patched in during the pass(1) work (see
[`../axionc/src/core.rs`](../axionc/src/core.rs) `normalize_alias_returns`) and the
`putStrLn`-borrow / `runCapture`-stdin fixes — all four were the *same* question answered
locally. Ground truth at design time (commit `a930c43`): `cargo test` verify 14 / run 223,
oracle 298, sanitize 130/118, fuzzer 1/7/42 clean.

## 1. The one question we keep answering

Axión decides ownership **per function**: a parameter is either *borrowed* (the caller keeps
it and frees it once) or *consumed*/`%1` (the callee owns and frees it). But four distinct
bugs this cycle all reduce to a question that is genuinely **per call site**, not per function:

> At `let r = g(a₀ … aₙ)`, for each argument `aᵢ`: does the caller **reuse** `aᵢ` after this
> call, and does `g`'s result **alias** `aᵢ`? The correct move/borrow/copy choice depends on
> the answer, which differs between two callers of the *same* `g`.

The cases it unifies (all currently patched or left open):

| Symptom | Where | Current state |
|---|---|---|
| conditional param-return UAF (`condRet`/`fromMaybe`/`chomp`) | core.rs `normalize_alias_returns` | String: copy-normalized (works, but copies even when the caller doesn't reuse). |
| same, over **Integer** | — | Reverted: naive copy clones fold **accumulators** per-iteration (14 fixtures) → O(n) regression on RSA/folds. Left as a **rare fail-open UAF**. |
| same, over **containers** | — | Empirically sound; no deep-copy primitive. |
| `putStrLn`/`putStr` param leak in a guarded body | core.rs `op_moves` | Fixed by reclassifying them as borrows. |
| dead owned `let x = producer in body` (x unused) | core.rs `scan_body` | Fail-closed (AX0911 rejects); rejects legit "ignored effectful producer". |

The common failure: a **function-level** rule must pick ONE answer for `g`, so it is either
unsound for the reuse case or wasteful/over-conservative for the no-reuse case. `condRet` and
`fromMaybe` and an Integer fold accumulator are the **identical Core shape** (`if c then param
else fresh`); only the *caller* distinguishes UAF from sound.

## 2. Root cause in the current model

Two concrete mechanisms make the function-level model wrong here:

1. **`rv.owned = any(branch owned)`** (verify.rs `merge_vals`): a mixed `if c then param else
   fresh` return is classified *owned*, so the interprocedural alias summary
   (`borrow_return_summary`) **discards** the param-alias branch → the caller drops the result →
   frees the aliased param → UAF. (This is exactly why `condRet` UAF'd and `orDefault`
   (param-OR-param, `rv.owned=false`) did not.)
2. **No liveness at call sites.** `compute_borrow_args` decides move-vs-borrow from the
   *callee* body alone (`body_moves`), with no knowledge of whether the *caller* still needs the
   argument. So a value that a callee consumes-and-returns cannot be "borrowed here, moved
   there" depending on caller reuse.

## 3. What to compute

Two analyses, both interprocedural, feeding the drop-insertion (`insert_drops`) and the
call-site ownership annotation (`null_borrow_result_keys` / the `moves{}` deltas):

**(A) May-return-param relation** — refine the existing `verify::compute_summaries`:
`ret_alias(g) ⊆ params(g)` = the args `g` may return as a *whole-value alias on ANY path*
(not just when the whole return is non-owned). This is the fix to the `rv.owned=any` blind
spot: track, per return, the *set of params it may alias* independently of whether *another*
branch is owned. (`orDefault → {0,1}`, `condRet → {1}`, `append/id → {}` because their returned
param is auto-`%1`/embedded — already excluded.)

**(B) Caller-side argument liveness** — a backward liveness pass over each caller body: for
`let r = g(… aᵢ …); rest`, is `aᵢ` (a heap var) **live in `rest`** (read/moved/embedded after
this call)? This is a standard use-set walk; the machinery already exists in fragments
(`term_mentions_any`, `fv_drop`, the `live_out` threading in `Elab::go`).

## 4. The decision, per call `let r = g(…aᵢ…)`

For each heap arg `aᵢ` with `i ∈ ret_alias(g)` (the result may be `aᵢ`):

| `aᵢ` live after the call? | Action |
|---|---|
| **No** (not reused) | **Move** `aᵢ` into `g` (today's behavior). `r` owns it; the caller drops `r`. No copy. This is the accumulator / `fromMaybe`-scalar / `append` case — **zero overhead**. |
| **Yes** (reused) | The caller keeps `aᵢ`. `r` may alias it → **do not drop `r`** as owned; and on `g`'s side the aliased return must not hand out a second owner. Realize by **copying at the call**: `let ac = copy(aᵢ); let r = g(ac …)` when `g` consumes, *or* mark `r` a borrow of `aᵢ` when `g` borrows. The copy is inserted **only here**, where reuse is real. |

Key win over the reverted normalize: the copy moves from the **callee** (fires for every
caller, including accumulators) to the **call site** (fires only on genuine reuse). An Integer
fold `foldl (\z acc -> …) …` never reuses `acc` after the combiner call → **no copy** → no
regression. `useBoth`/`relJoin` do reuse → copy exactly once.

Copies needed: `String` → `strAppend x ""`; `Integer` → `axion_bignum_copy` (the reverted
runtime fn, re-land it); containers → a generated per-type deep-copy (the one genuinely new
runtime piece — symmetric to the `axion_drop_T` destructor generator; defer to a later phase,
fail-closed until then).

## 5. Integration points (pipeline order in `core::to_core`)

1. after `collapse_var_cases`, before `compute_borrow_args` (where `normalize_alias_returns`
   runs today) — replace the callee-side rewrite with **nothing**; the callee stays as written.
2. compute `ret_alias` (extend `verify::compute_summaries`; it already runs as
   `borrow_return_summary`).
3. new **call-site pass** after `compute_borrow_args` + `borrow_ret`: walk each fn, run arg
   liveness, and for each `(call, aᵢ)` with `i ∈ ret_alias(g)` **and** `aᵢ` live after → insert
   the copy (or borrow-mark). This is where `reclaim_cond_escape` already lives, so it composes
   with the existing conditional-escape reclamation.
4. `insert_drops` unchanged — it now sees either a moved arg (drop `r`) or a copied arg (drop
   both the copy's result and the still-owned original), both already handled.

The dead-binding leak (§1 row 5) falls out for free: `let x = producer in body` with `x`
unused is `ret_alias`-irrelevant, but the same liveness pass identifies `x` dead → drop it at
the binding (today `scan_body` loses it through the `x = _t1` rename; the liveness pass tracks
the rename's source and drops the real owner).

## 6. Soundness & validation

- **Soundness argument:** a copy is inserted iff (result may alias `aᵢ`) ∧ (`aᵢ` reused) — the
  only configuration that double-frees. Everywhere else ownership is unchanged, so the existing
  drop-verifier (AX0910) proof still applies; the verifier re-derives `ret_alias` from the
  emitted Core and re-checks, exactly as it does for `borrow_return_summary` today.
- **The accumulator gate:** add a bench kernel that folds Integers (RSA-shaped) to
  `scripts/bench.sh` so the perf-regression gate *proves* no per-iteration copy is introduced —
  the exact regression that killed the naive Integer extension.
- Standard gauntlet each phase: verify / run / oracle / sanitize / fuzzer / clippy. Extend the
  differential fuzzer to emit the mixed `if c then param else fresh` shape over String / Integer
  / List with reusing and non-reusing callers, so both the UAF and the over-copy are fuzzed.

## 7. Phasing (judgment-first, like per-field-ownership)

- **R-1** — `ret_alias` refinement in `verify.rs` + `--emit` facts + unit tests; no lowering
  change yet (pure analysis, oracle-neutral).
- **R-2** — caller-side liveness pass + the call-site copy/borrow decision; **retire**
  `normalize_alias_returns` (the String copies move to call sites — expect the `str_helpers`
  `chomp` snapshot to change back, and `mixed_param_return_reclaim` to stay green with the copy
  now at `useBoth`, not inside `chomp`).
- **R-3** — re-land `axion_bignum_copy`; Integer now copies **only** on reuse (accumulators
  untouched — verified by the new bench kernel). Fixture: `mixed_param_return_integer`.
- **R-4** — the dead-binding leak (drop the real owner through renames).
- **R-5** — container deep-copy generator (per-type `axion_copy_T`); lift the container
  fail-closed. Optional / largest; only if a real workload needs it.

## 8. Risks & non-goals

- **Not** full arena/region *inference* (that was the heavier reading of "region ownership");
  this is call-site reuse analysis, which is what the surfaced bugs actually need and is
  incremental over the existing summaries.
- Liveness precision: be conservative (assume live) on anything not provably dead — a spurious
  "live" only inserts an unnecessary copy (perf, not soundness), and R-2's bench gate catches
  hot-path over-copying before it lands.
- Interaction with `%1`/auto-consume: a param already `%1` (append/reverse/embedded) is a real
  consume — excluded from `ret_alias` copying, as today.

## 9. Related

[`per-field-ownership.md`](per-field-ownership.md) (the `%1`-field split, same "which slot
moved" flavor), [`delta-design.md`](delta-design.md) (the `op_delta_effect` authority the
move/borrow classification must stay in sync with), [`validation-report.md`](validation-report.md).
Memory: `axion-conditional-param-return-uaf`, `axion-drop-verifier`.
