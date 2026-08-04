# Next steps: gates done, §9.1 amendment + per-field ownership design doc

## Status: gates — DONE (this session, all green)

- `AXION_CLANG=clang ./scripts/tsan.sh` — 8/8 concurrent session fixtures race-free
- `./scripts/session-scaling.sh` — compute-bound scales with threads; global-mutex
  ceiling ~10-62 M ops/s documented
- `AXION_CLANG=clang ./scripts/concurrency-bench.sh` — 4-thread speedup: Axion 3.50
  vs C 3.75 / Rust 3.78 (fib-dominated workload, expected gap)
- Δ agreement on the inplace fixture verified: `--emit delta inplace_update.axi`
  → `bump c = ok` (inplace base escapes), `main = ok — drops: c1`, `Δ ok`

## Step 2: close §9.1 in docs/delta-design.md (small, after exiting plan mode)

Edit the first bullet of "## 9. Open decisions":

- Strike through the `UpdateRecord` item: the fixture gap is closed by
  `inplace_update.axi` (`bump c = c { val = 99 }` — Linear Elision §2, 1 alloc
  == 1 free, in the 132-fixture oracle and 103/103 check-delta).
- Keep the Δ-3 amendment text (base escapes via `op_delta_effect`).

## Step 3: per-field ownership design doc (spec/studies/per-field-ownership.md)

Design only — no code changes. Structure:

1. **Goal**: constructor component typing from the paper — `%1` fields carry
   their own Δ; extracting a `%1` field from a linear scrutinee (`Field`-ret,
   `case` arm) transfers ownership of *that field* while the scrutinee's shell
   and remaining fields must still be reclaimed.
2. **Kills the Field-split rule**: today a heap field extracted out of a linear
   scrutinee forces a shallow shell-only free (core.rs ~3477/3757,
   `land_deepdrop_safety`); with per-field ownership the remainder is
   deep-dropped per field instead of shallow-freed.
3. **Δ judgment**: `Res` gains a per-field ownership map; `op_delta_effect`
   moves per-field on `Field`/`case` extraction; destructor keys become
   field-aware (`axion_drop_*` skips the transferred field).
4. **Phases** (each gated: oracle, check-delta, sanitize, differential, bench):
   - P-1 judgment extension + `--emit delta` facts (no behavior change)
   - P-2 codegen: field-aware destructors; coresnap regen with rationale
   - P-3 fixture updates (`land_deepdrop_safety` flips shallow→per-field deep)
5. **Bridge**: dependent sorts (§7-4 of memory-model-options.md) — deferred,
   noted only.

## Open question for the user

- Step 3 deliverable is the design doc only (approved scope). Whether to also
  implement P-1/P-2 in this session is a separate decision.
