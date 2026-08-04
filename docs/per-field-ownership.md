# Design plan — per-field ownership (`%1` fields with their own Δ)

**Status:** DESIGN ONLY (the "Future" row of docs/delta-design.md §8). No code
changed by this document. Implements the paper's **constructor component
typing**: each `%1`-annotated constructor field owns its own linear resource.

**Goal:** close the Field-split gap — today a linear scrutinee whose heap field
is extracted and moved out (`case p of P a b -> use a`, `%1`-field reads) can
only be *shallow*-freed (shell only): the remaining fields are conservatively
leaked, because "one of them may have been moved". With per-field ownership the
compiler knows *which* slot left, and frees the shell **plus every remaining
field** via a field-aware destructor. Safe (never double-free) and leak-free
(no conservative payload leaks).

## 1. Why it happens (the root cause)

A `case` arm that moves a heap field of the scrutinee out transfers ownership of
that field. The destructor `axion_drop_T` frees the shell and **all** payload
slots — so after a transfer it cannot be used: it would double-free the moved
field. Today's guard is the **Field-split rule** (core.rs ~3471/3757,
`transfers_heap_field`): if *any* arm transfers a heap field (or returns a value
that may alias a payload), the scrutinee gets a **shallow (shell-only) free** —
safe, but every payload left behind **leaks**. `land_deepdrop_safety` pins the
all-or-nothing behavior (the `Node l r` arm transfers both children → shallow).

The front end already knows more than this: `%1` constructor fields are typed
and their reads classified as *moves* by `arg_mode(ctx.field_mults…)`
(check.rs:1631/1849/2514). What is missing is the **reclamation side**: the
destructor keys (`RecordInfo::field_is_heap`, `con_drop_slots`) are field-type
based, not field-ownership based, so the pipeline cannot express "free this
shell minus slot *i*".

## 2. Success criteria / non-goals

**Must hold:**
- A `case`/`Field` that moves out a `%1` field leaves the **remaining** fields
  reclaimed: `allocs == frees` (ASan/LSan), across `--dev`/`--release` — no
  conservative leaks on the extracted-field path.
- Never a double-free or UAF: the transferred slot is **excluded** from the
  remainder destructor; the Δ judgment proves the exclusion.
- Semantics unchanged: GHC oracle agreement; the 132-fixture oracle re-verified
  (snapshot regenerated only with documented, intended changes).
- The all-or-nothing shallow free is replaced — `land_deepdrop_safety`'s `Node`
  arm becomes a *shell-only remainder drop* (both slots moved out), and a new
  fixture covers the mixed arm (`Node l r -> sumTree l` — `r` must be
  deep-dropped, not leaked).

**Non-goals (honest boundary):** dependent multiplicities (§7-4 of
memory-model-options.md — the deep bridge) stay out; `%1` fields remain
independent of type indices. Non-`%1` fields are untouched (they may alias —
borrow semantics as today). Buffer/IO "fields" are not constructors — unaffected.

## 3. The mechanism — remainder drops

For a move-out of slot `i` of a linear scrutinee, emit a **remainder drop**:
`drop … : T skip i` — frees the shell and every drop slot except `i`. Lowering:

- **Front-end (done in principle):** `%1` field reads already move
  (check.rs `arg_mode`/`field_mults`); the *elaboration* of a `case` arm or
  `Field`-ret now records the set of transferred slots instead of the boolean
  `transfers_heap_field`.
- **Δ judgment:** a `%1`-field extraction enters the binder into Δ as its own
  resource (drop key = the slot's type key, parent = the scrutinee resource);
  the scrutinee's remainder stays live until the arm exit, where it is drained
  by the remainder drop. Rules added: `(Field·owned)` — `%1` field of a linear
  record transfers; `(Drop·skip)` — a remainder drop frees all slots except the
  transferred ones, which must have entered Δ.
- **Destructors:** the `gen_destructors`/mono template generates, per
  constructor, the skip variants it needs: `axion_drop_T_skip_i` (shell + all
  slots except `i`; recursive calls become skip-variants of the field types).
  Only reachable variants are emitted (the seeds come from the lowering pass,
  exactly like the mono-destructor seeds).
- **Core:** `Term::Drop` gains a skip set (`Vec<usize>` of slot indices, or the
  empty remainder for a full deep drop) — the annotated dump prints it; the
  judgment and the codegen read the same field.

This **kills the Field-split rule**: `transfers_heap_field` and the
alias-shallow-free fallback (core.rs:3757-3784) collapse into ordinary
remainder drops; the alias case is handled by the existing borrow rules (a
*borrowed* field never transfers, so its slot is dropped as today — no change
in safety).

## 4. What has to change (concretely)

1. **check.rs** — expose per-arm transferred-slot sets (replacing the
   `transfers_heap_field` boolean use in `Elab`); the `%1`-field move
   classification (already present) is the authority.
2. **core.rs** — `Term::Drop` skip set; `Op::Field` on a linear `%1` record
   becomes a transfer; `Elab::case_arms`/ret-elaboration emit remainder drops;
   `transfers_heap_field` deleted.
3. **delta.rs** — `Res` stays `(key, parent)`; new rules for field-extraction
   entry and skip-set drains (`op_delta_effect` gains per-field moves on
   `Field`/`case`); `--emit delta` prints transferred slots.
4. **codegen.rs / destructors** — skip-variant templates seeded from lowering
   (reuses the mono-destructor machinery, polymorphic-drop-plan.md §3);
   `axion_drop_T_skip_i` skips slot `i`'s free.
5. **Fixtures** — `land_deepdrop_safety` re-anchors (shell-only remainder);
   new `land_field_split_owned.axi` (mixed arm, must reclaim the remaining
   field); a `%1`-field + mono-destructor interaction fixture.
6. **Docs** — this plan's "Implementation" section, delta-design.md §6/§8
   (Field-split row strikes through; future row moves to done).

## 5. Phases (gates per phase)

Same discipline as Δ-1..Δ-5: behavior-identical where possible; every step
green on oracle / check-delta / sanitize / differential / bench / clippy / fmt.

| Phase | Content | Deliverable / gate |
|---|---|---|
| **F-1** | Judgment first: `%1`-field extraction rules + skip-set draining in `delta.rs`, `--emit delta` facts; **no codegen change** — checker-only on today's Core (skip sets always empty). | checker accepts 103/103; new unit tests (extraction enters Δ, skip-drain classification, tamper negatives); oracle 132/132. |
| **F-2** | Lowering: `Term::Drop` skip set; elaboration emits remainder drops on moved-out `%1` fields; `transfers_heap_field` deleted; Field-split replaced. | `land_field_split_owned.axi` lands: `allocs == frees` (sanitize, 33/27+); `land_deepdrop_safety` re-anchored with rationale; snapshot regenerated (intended); oracle 132/132, check-delta 103/103, differential 3/3, bench. |
| **F-3** | Codegen: skip-variant destructors (`axion_drop_T_skip_i`) seeded from lowering; skip-set annotated dump. | mono-destructor interaction fixture; oracle 132/132, check-delta 103/103, sanitize 33/27, differential 3/3, bench, clippy/fmt clean. |
| F-4 | Docs + open-decision audit (delta-design.md §9: Field-split bullet strikes through; §10 anchors note the component typing). | review-only. |

## 6. Residual risks

- **Skip-variant explosion**: one variant per transferred slot per constructor —
  bounded by slots × transferred-slot patterns that actually occur (seeded from
  lowering, like mono destructors); pathological nesting is documented, not
  bounded.
- **Alias interplay**: the arm-returns-aliasing-payload case must keep borrowing
  semantics — F-2 keeps `Field`/borrow paths on non-`%1` fields untouched; the
  alias rule stays conservative (shallow) for non-`%1` payload aliases.
- **Oracle churn**: the annotated dump changes (skip sets, remainder drops) —
  every regeneration is deliberate and documented, per the dump-oracle contract.
