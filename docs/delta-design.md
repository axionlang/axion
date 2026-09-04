# Δ — a single linearity judgment over the ANF Core

Status: design doc + realization log. Phase A′ (drop-type annotations) is done and
verified; this document designed the Δ validator that (a) makes Auto-Drop a *proven*
single judgment instead of three ad-hoc analyses, and (b) collapses the dual
analysis (`check.rs` DropPoints ↔ `core.rs` insert_drops).

Source: *Lazy Linearity* (Mesquita & Toninho, POPL 2026; arXiv:2511.10361;
`spec/studies/Lazy_Linearity.pdf`, text at `/tmp/opencode/ll.txt` + `ll2.txt`).

> **REALIZATION UPDATE (2026-09-04) — the single Δ judgment is `verify.rs`, not
> `check_all`.** The judgment designed below (§5) was implemented as
> `delta.rs::check_all` and served as the Δ gate for a time. But the reclamation
> (`core.rs::insert_drops`) kept advancing while `check_all` drifted behind it, and a
> newer, **sound** judgment matured in parallel: the **drop-balance verifier**
> (`src/verify.rs`, default-on `AX0910`/`AX0911`), an abstract interpretation over the
> *final* drop-inserted Core that proves no double-free / use-after-free / bad-free /
> gate-worthy leak, is **ASan-cross-checked and 0-false-positive**, and uses the same
> `delta::op_delta_effect` authority. It was proven to **subsume** `check_all` (the
> `delta::tests::verify_catches_*` tamper battery, née the Step-0 subsumption
> cross-check), so `check_all` was **retired** and `verify.rs` is now the sole soundness
> judgment and the blocking Δ CI gate (`scripts/verify-gate.sh`). See
> [`delta-consolidation-plan.md`](delta-consolidation-plan.md). The design's *goal* —
> one proven judgment, no drift-prone duplication — is thus realized, via `verify.rs`
> rather than `check_all`. What survives from `delta.rs`: `op_delta_effect` (the shared
> multiplicity axiom table), `dump_annotated` (the oracle-locked `--emit core`
> annotations) with its `Ck` state machine, and `check_drop_coherence` — the §6
> coherence cross-check, now the standalone **non-soundness** guard `--check-coherence`
> (`scripts/check-coherence.sh`, guarding that the LSP-shown DropPoints match the emitted
> Core). The phase table in §8 below is kept as the historical design log; read it
> through this update.

---

## 1. Purpose and scope

Today, "where does each heap resource die" is decided by **three separate
implementations of the same idea**:

1. `check.rs` — liveness analysis emitting `DropPoint { func, var, ty, span,
   reason }` (`check.rs:41`), collected in `Analysis { drops, inplace, arenas }`
   (`check.rs:72`), emitted at `check.rs:1292`, consumed only by the debug
   `print_drops` (`main.rs:154` / `:864`). **It decides nothing at runtime.**
2. `core.rs` `insert_drops` (~`core.rs:3213`) — a second, independent walk of the
   Core (droppable sets, `fv_drop`/`fv_op` liveness, escape/alias/transfer
   heuristics, `compute_borrow_args` at `core.rs:2989`) that inserts `Drop` terms.
3. Phase A′ annotations (`Op::ty`, `CoreFn::owned_drop_ty`) — the *data* the walk
   reads, now fully resolved at lowering.

> **Current ground truth (2026-08-06, [`validation-report.md`](validation-report.md)):**
> dump-oracle 147/147, check-delta 118/29, sanitize 45/37, tsan 8/8, differential 3/3,
> `cargo test` 156. The per-phase counts in this doc are historical snapshots, kept as a log.

The gates (dump-oracle 132/132, sanitize 33/27, differential 3/3) hold these
together *dynamically*. The Δ judgment replaces this with a **static proof**:

> After lowering + drop insertion, the annotated Core must type-check under the
> Δ judgment. A successful check *proves*: no double-free, no use-after-free, no
> silent leak — for every fixture, statically, at compile time.

## 2. The paper in one page

Typing judgment `Γ; Δ ⊢ e : τ` with usage environments Δ over linear resources.
Δ-variables are bound by (rec)let and case patterns, annotated with their usage
environment, e.g. `x : [Δ]σ`.

Key rules (Fig. 4–5 of the paper):

- `(VarΔ)`: `Γ, x:Δσ; Δ′ ⊢ x : τ` requires `Δ = Δ′` — using a Δ-bound variable
  consumes exactly its usage environment.
- `(Split)`: `Γ; Δ1, Δ2 ⊢ e : τ` — contexts split; a linear resource must be
  used exactly once across the whole program.
- `(Let)`: a let splits Δ between the binding and the body; the binder inherits
  the binding's residual resources.
- `(CaseWHNF)` / `(CaseNotWHNF)`: typing a `case` on a non-WHNF scrutinee needs
  the WHNF extraction judgment `Γ; Δ ⊩ e : σ ⋗ Δ′` plus *irrelevant* resources
  `[Δ]` (linear, but only consumable indirectly via the case binder or pattern
  variables — §3.6.1–3.6.2 of the paper).
- `(Alt*)`: pattern alternatives; the linear components of a constructor pattern
  are Δ-variables; non-matching alternatives are treated as non-WHNF.
- Multiplicity polymorphism `Λp.e`; strictness orthogonality (`Unboxed`).

Preservation: type preservation + progress of the evaluation state `(Θ | e)`
(Theorems B.7–B.10); rewrite safety Theorems C.1–C.12 (inlining, β, β-with-
sharing, case-of-known-constructor, case-of-case, full-laziness, commuting
lets, η, binder-swap).

## 3. Why strict ANF collapses the hard case

The paper's complexity (§3.5–3.6) exists because lazy evaluation makes the
*scrutinee of a case an unevaluated expression*. In the Axion Core none of that
survives:

- The Core is strict ANF: every `Rhs::Case` / `Rhs::If` scrutinee is an `Atom`
  (literal or variable), i.e. **already in WHNF** by construction. The resources
  consumed by evaluating an expression were already accounted in the `let` that
  bound the atom.
- Therefore `(CaseNotWHNF)`, the `⊩` extraction judgment, and irrelevant
  resources `[Δ]` **never fire** in the ANF. The case rule reduces to
  `(CaseWHNF)` with the Δ of the scrutinee distributed over the arms through
  the pattern's linear binders.
- β-with-sharing (C.3) and full-laziness (C.7) are lazy-only rewrites — inapplicable
  by design (zero laziness in Axion; verified in Phase 0). The remaining
  C-theorems transfer directly as the *rewrite contract* (§7).

This is the design's central simplification: **an ANF-strict port of the
judgment is ~30 lines of rules, not the full paper calculus.**

## 4. The Core contract (what the judgment sees)

```
Term := Let(name, Rhs, Term) | Drop(name, Option<data>, Term) | Ret(Rhs)
Rhs  := Op(Op) | If(Atom, Term, Term) | Case(Atom, [(CPat, Term)])
CPat := Int | Var(name) | Wild | Tuple([CPat]) | Con(con, [CPat])
Atom := Int | Float | Str | Var(name)
```

Facts that make the judgment decidable:

- **Pattern variables are bound by the pattern, not by a `let`.** An arm body
  may refer to its `CPat::Var` names freely (`core.rs:3643`); they are
  Δ-variables in the paper's sense.
- **Multiplicity is explicit and precomputed.** `ast::Field.mult` (`%1`) for
  record fields (ast.rs:139); `compute_borrow_args` (`core.rs:2989`) for call
  positions (borrowed = non-`%1` position read only locally — except view
  positions like `drop`'s list, whose result shares the argument's cells and is
  therefore moved — auto-detected by `core.rs::destructures_and_embeds_recursive`,
  §9-7); `owned_params` /
  `owned_drop_ty` for function parameters (core.rs:190/194). The judgment reads
  *exactly this* — no re-derivation.
- **Drop-type keys are annotated** (Phase A′): `CallDirect(.., Option<String>)`,
  `MakeCon { ty }`, `MakeRecord { ty }` (core.rs:59/75/84), `CoreFn::owned_drop_ty`.
  `Some(k)` = the value is a heap object of data type `k` (deep-drop capable);
  `None` = unknown/flat.
- **The recursive destructor is a CoreFn** (`axion_drop_<T>`), generated after
  drop insertion; it frees the shell and recurses over `%1`-heap fields.

## 5. The judgment

State: `Γ; Δ ⊢ t : Δ′` — term `t` with live linear resources Δ terminates with
Δ′. Γ maps variables to either *resource* (in Δ) or *ordinary* (freely
duplicable). Resources are named by their variable; each carries its drop-type
key `(var, Option<data>)`.

Invariants enforced by the rules:

- **Use = consume for resources.** Using a resource in a *moving* position
  removes it from Δ; using it in a *borrowing* position keeps it. Using it
  twice in moving positions is a type error (double-use); using it after its
  `Drop` is a type error (use-after-free).
- **Drop = explicit consumption.** `Drop x ty` requires `x ∈ Δ`; it removes
  `x`. `ty = Some(k)` additionally requires that all of `x`'s payload resources
  were already consumed or are freed by the destructor (deep-drop soundness);
  `ty = None` (flat) requires `x`'s payload resources to be **empty or already
  moved out** (shallow free, conservative).
- **Branches balance.** Both arms of `If` and all arms of `Case` must leave the
  *same* outer Δ′ (this is today's branch-balancing, made a typing rule).
  Pattern-bound payloads are deliberately **not** balanced: they are the
  scrutinee's sub-objects — freed by its drop, or leaked with it (the deferred
  extracted-field gap) — the reclamation analysis never drops a payload on its
  own.
- **No silent leaks.** A function's final Δ′ must be exactly the resources
  carried by the returned value (the `(Ret)` rule). A `%1` parameter the body
  never touches never enters Δ (it is never freed — matches the reclamation
  analysis; the front-end "dies at entry" DropPoint is cross-checked by
  `check_drop_coherence`, Δ-3 move 2).

### Rules

```
Atom/literal            Γ; Δ ⊢ a : a      (no resource named by a literal)

(Var·move)   x ∈ Δ, position p is Move(x)
             Γ; Δ ⊢ p : Δ ∖ {x}
             (a `%1` parameter enters Δ lazily at its first Move / Drop — a
             parameter the body never moves is never a resource)

(Var·borrow) x ∉ Δ or position p is Borrow(x)
             Γ; Δ ⊢ p : Δ

(Let)        Γ; Δ ⊢ op : Δ1      Δ1 ⊢ (produced) = Some(Φ) ⇒ x ∉ Δ1, x : Φ enters Δ
             Γ; Δ ⊢ Let x = op in t : Δ2 ⇐  Γ, x; (Δ1 ∖ {x}) ∪ Φ ⊢ t : Δ2
             (op scalar ⇒ Φ = ∅; x is ordinary)

(Drop)       Γ, x ∈ Δ; Δ ⊢ Drop x ty in t : Δ′  ⇐  Γ; Δ ∖ {x} ⊢ t : Δ′
             + deep-soundness: ty = Some(k) ⇒ no payload of x was moved out /
             freed separately before the drop (the `split` set); ty = None ⇒
             no constraint (a flat free of a shell with live payloads is legal —
             the payloads leak or are freed by the caller)

(If)         c is an Atom, c ∉ Δ (conditions are scalars in practice; if c ∈ Δ,
             the condition consumes it — never emitted today)
             Γ; Δ ⊢ If c th el : Δ′  ⇐  Γ; Δ ⊢ th : Δ′  and  Γ; Δ ⊢ el : Δ′

(Case)       s an Atom. Let Δ_s = Δ if s ∈ Δ else ∅.
             For each arm (ρ, t_i):
               • ρ's linear binders b_j (Con fields with field_transfers_heap,
                 Tuple components) enter the arm as *parented* resources — used
                 only by the deep-drop-soundness check, never by balancing —
                 and s is *borrowed* inside the arm if used (the case binder),
               • the arm must consume Δ_s entirely by its exits: either by
                 moving s (or its payload binders) out of the arm, or by a
                 trailing Drop (deep if no payload was moved out, else flat —
                 exactly today's deep_safe test),
               • Γ; Δ_i ⊢ t_i : Δ′  with the *same* outer Δ′ for every arm.
```

### The axiom table — one rule per Op

Every `Op` has a consumption signature `(moves, borrows) → produces`:

| Op | Moves (consume if ∈ Δ) | Borrows (keep in Δ) | Produces |
|---|---|---|---|
| `Atom(a)` | a resource named by `a` — becomes ordinary (alias; the reclamation analysis never drops an aliased value) | — | the atom itself (value ret) |
| `Prim`, `PrimF`, `IntToFloat`, `FloatToInt`, `FloatUnary` | — | both operands | scalar (∅) |
| `CallDirect(f, args, ty)` | args at non-borrow positions (`compute_borrow_args`) | args at borrowed positions | `Some(ty)` if `ty = Some(k)` — binder enters Δ as `(x, k)` carrying the moved args; else ∅ |
| `CallClosure(f, args)` | all args; `f` if it is a bound variable (a top-level function address is not a variable — session/runtime entries) | — | ∅ — an indirect call's result is never a droppable (`op_produces_heap` does not cover it) |
| `MakeClosure { captures }` | all captures | — | heap, `None` key — binder enters Δ with `(x, None)` |
| `MakeTuple(args)` | all args | — | heap — binder enters Δ with the moved args |
| `MakeCon { args, ty }` / `MakeRecord { fields, ty }` | args/fields with `mult = %1` | the rest | `Some(ty)` — binder carries the moved `%1` fields |
| `UpdateRecord { base, fields }` | `base` if ∈ Δ (ownership transfer), + `%1` new fields | `base` otherwise | the *same* Δ as base (minus replaced fields) + moved fields; `inplace` is an implementation flag — identical Δ effect |
| `Field { name, rec }` | — | `rec` | borrowed sub-object: ∅ formal, but see split rule (Ret) |
| `LoadRaw`, `StoreRaw`, `FuncAddr` | — | all atoms | ∅ / value |
| `PutStrLn`, `PutStr`, `ShowInt` | — | arg | ∅ |
| `WithArena { parent, clos }` | — | both (arena reset bulk-reclaims; arena-allocated cells are not Δ resources) | ∅ |
| `ArenaAlloc`, `Promote`, `ArenaMark`, `ArenaRelease` | — | args | ∅ |
| `RtCall { args, returns }` | **all args** — the reclamation analysis marks them escaped (`scan_op_escapes`), so the caller never frees them; `axion_free` is just the runtime free | — | ∅ |
| `Ffi` | all args (escaped — same rule as `RtCall`) | — | ∅ |
| `Unsupported` | — | — | **validator error** |

`(Ret)` and the field-split rule:

```
(Ret)        Γ; Δ ⊢ Ret(rhs) : Φ(rhs)
             where Φ = the resources the rhs produces. If Δ ≠ Φ: resources in
             Δ ∖ Φ are leaked → type error. (A function must consume or return
             every resource it owns; %1 params not consumed are returned.)
             Payloads alive at the return are not leaks — they are sub-objects
             of a scrutinee, freed by its drop or leaked with it.

(Field-split) Ret(Op(Field { name, rec })) with rec ∈ Δ:
             the returned value *aliases a payload of rec*. The shell of rec
             must die here as a flat Drop (drop-type None), leaving the payload
             alive in the returned value. This is today's `transfers`-guarded
             shallow-free (`core.rs:3676`), made a typing rule. The stricter
             form (returning a payload as a *new owned* resource) requires
             per-field ownership (§9), future work.
```

### Why this is complete for the current pipeline

- `Let` with `produces = Some` regenerates the resource at the binder — this is
  the Phase A′ annotation `ty` consumed as a typing rule (no more
  `op_produces_heap` / `op_result_may_be_heap` / droppable-set re-derivation).
- `Case`'s Δ_s consumption + arm balancing replaces `transfers[]`,
  `result_may_be_heap`, `collect_payload_aliases`, and the `union.difference`
  balancing loop (`core.rs:3679–3684`) — one rule instead of four heuristics.
- `(Var·move)` + `compute_borrow_args` replaces `fv_op`'s
  read-position classification.
- `(Ret)` + `(Field-split)` replaces the escape/alias heuristics.

## 6. Collapsing the dual analysis

Today (`insert_drops` at `core.rs:3213` re-derives what `check.rs:1292` already
computed). Target architecture, in three moves:

1. **The axiom table is the only multiplicity authority.** `op_delta_effect(op)
   -> (moves, borrows, alias, produces)` is implemented once in `delta.rs`
   (**done in Δ-3**); the old `op_produces_heap`, `scan_op_escapes` and the
   read-position classification in `fv_op_in` become *uses* of it
   (`scan_op_escapes_ret` deleted — its atom case was already the alias;
   `op_result_may_be_heap` keeps its own match: it proves *scalar-ness*, not
   ownership — a different predicate over the same Phase A′ annotations).
2. **DropPoints become the input to insertion.** The two analyses become one
   pipeline: `check.rs` finds death points, `core.rs` writes them, `delta.rs`
   proves them. **Δ-3 finding:** Core terms carry no spans, and a `DropPoint`
   is `(func, var, ty, span, reason)` computed on the *AST* — a literal
   span-based match into Core is not possible without spans on `Term`/`Op`
   (deferred to the Future row). **Done instead:** a coherence cross-check —
   `delta.rs::check_drop_coherence` re-runs the judgment per function and
   verifies the two engines agree on the *classification* of every `%1` heap
   param: a "dies at entry (never used)" DropPoint ⇒ the param stays in
   `owned` to the end (the Core never touches it); "dies after the last read"
    ⇒ it entered Δ (borrow at a `case` scrutinee, a `Drop`, or a move) and was
    reclaimed. Violations are drift between the liveness engines; they surface
    through `--check-delta` (same exit-code contract).
    **Δ-5 adds the position dimension**: `%1` heap params whose DropPoint says
    "dies after the last read" also carry a *death span*; a Core `Drop` that
    drains the param must be anchored **at or after** that span
    (`anchor.1 > death.0`). Anchors are per-*statement*: every Core node
    carries the span of the source statement that produced it (the pre-Δ-5
    anchors were whole lines, too coarse to prove "after the last read").
    `NO_SPAN` anchors (generated code: destructors, session machines) are
    unverifiable and skipped. This catches a use-after-free the classification
    check cannot see: a drain placed before the last read still drains *at the
    exit*, so the sets agree — only the order differs. Δ-5 landed with a span
    fix in the lowering rewrite (`core.rs::expr` rebuilt application exprs
    with `head.span()`, so anchored statements ended before their own
    arguments — every drop-on-argument fixture looked misplaced); the rewrite
    now extends each rebuilt app's span to its last argument, and the
    `linear_move.axi` take case is locked by a regression test (positive +
    span-collapse tamper negative).
3. **The Δ checker is the judge.** It runs on the annotated Core (after drop
   insertion, before destructor generation) and reports a *compiler-internal*
   error on any violation — turning today's dynamic gates into a static proof
   for every fixture. `--emit core` prints the Δ annotations (deterministic;
   the dump-oracle keeps its snapshot semantics).

The debug `print_drops` (`main.rs:154/864`) then shows exactly what the Δ
judgment is checking — the same facts, one source.

## 7. The rewrite contract (C.1–C.12 for the Core)

The Axion Core performs no rewrites today (lower → insert_drops → destructors
→ codegen is a single descent), but the contract is cheap and future-proofs
every optimizer pass (defunctionalization, session lowering is already a Core
generator, mono destructor generation):

- **Rule:** every Core→Core pass must either (a) be Δ-preserving (the paper's
  C-theorems state exactly which rewrites are safe: inlining C.1, β C.2,
  case-of-known-constructor C.5, case-of-case C.6, commuting lets C.8, η C.10–C.11,
  binder-swap C.12), or (b) re-validate: run the Δ checker after the pass.
  β-with-sharing (C.3) and full-laziness (C.7) are lazy-only and **inapplicable**
  (strict ANF — §3).
- **In practice (updated 2026-09-04):** the soundness judgment runs in CI after every
  pass that exists today and after any pass added later. A future optimizer gets the
  paper's theorems as its license and the judgment as its CI. Today the descent is a
  single pass, so the `delta` job of `.github/workflows/ci.yml` runs the gate scripts —
  `dump-oracle.sh` (every fixture's annotated dump byte-matches the stored snapshot; an
  *unintended* change of behavior cannot land) and **`verify-gate.sh`** (the **drop-balance
  verifier** proves no corruption / no gate-worthy leak over the final Core across the whole
  corpus — the realized single judgment; see the top-of-file update, `check_all` retired);
  the `axionc` job runs the unit suite, which locks the dump format
  (`annotated_dump_locks_format`) and the verifier's behavior, and `bench.sh` (also in the
  `delta` job) is a runtime correctness gate — dev/rel vs C/Rust must agree per kernel. The
  §6 coherence cross-check survives as the standalone, opt-in `check-coherence.sh` (not run
  in CI).
- The C.9 special case (case-of-case with an inner let) is exactly the
  `Let`/`Case` commutation the strict ANF form permits — no lazy caveats.

## 8. Implementation phases (gates per phase)

Same discipline as Phase A′: behavior-identical at every step, gates green
oracle 132/132, sanitize 33 without corruption / 27 leak-free, differential 3/3,
bench no regression.

| Phase | Content | Deliverable / gate |
|---|---|---|
| **Δ-1** | `delta.rs`: the judgment of §5 over the *current* annotated Core (no behavioral change). Runs after `insert_drops`; reports only. | `--check-delta` passes 103/103 front-end-OK fixtures + all 7 examples (gate `scripts/check-delta.sh`); oracle 132/132 green. ≈500 lines. |
| **Δ-2** | Annotate the Core dump with per-`let` usage envs (dump format extension); regenerate snapshot. | `delta.rs::dump_annotated` replaces `core::dump` in `--emit core`: every `let`/`ret` carries `; Δ{…}` (live resources entering the node), `· moves{…}` (resources the op consumed), `· makes K` (produced deep-dropable key / `heap`). All sets sorted; lines unannotated by design (`drop`, headers). Snapshot regenerated: oracle 132/132 green; checker gates unchanged (103/103, 33/27 sanitize, 3/3 differential, bench). |
| **Δ-3** | Collapse: `op_delta_effect` becomes the single authority; `insert_drops` consumes `check.rs` DropPoints; delete re-derived heuristics. | **move 1 done**: `delta.rs::op_delta_effect(op, ba) -> (moves, borrows, alias, produces)` is the one multiplicity table; the Δ judgment (`Ck::op`), `op_produces_heap`, `scan_op_escapes` and the read positions of `fv_op_in` all consume it (`scan_op_escapes_ret` deleted). Arena operands (`WithArena.parent`, `ArenaAlloc/Mark/Release`, `Promote`) stay a documented reclamation-side caveat. The collapse surfaced a latent bug: the old escape analysis forgot the `UpdateRecord` **base**, so `land_tuple_upd.axi` emitted `drop r : Rec` *before* `update r` (a use-after-free in the emitted Core, masked because the fixture is sanitize-skipped); the base now escapes — ownership transfers at the update, matching the `UpdateRecord` axiom. **move 2 done (coherence, not literal consumption — §6)**: `check_drop_coherence` cross-checks the judgment's param classification against the front-end DropPoints; 4 new unit tests (2 positive, 2 drift-tamper negatives). Snapshot regenerated (intended change): oracle 132/132, check-delta 103/103, 33/27 sanitize, 3/3 differential, bench, 141 cargo tests. |
| **Δ-4** | Wire the checker into CI after every Core pass (the §7 contract); add `--emit delta` debug view. | **done**: the `delta` job of `.github/workflows/ci.yml` runs `dump-oracle.sh` + `check-delta.sh` + `bench.sh` on every push/PR (the §7 contract — snapshot oracle + checker gate + runtime agreement); `--emit delta` prints the judgment's per-function verdicts with the facts the annotated dump cannot show (drops in the judged Core, never-used `%1` params, the coherence agreement totals). The coherence per-function logic is shared with `--check-delta` (`drop_sets`, `coherence_violations`). 4 new unit tests (facts + format lock + determinism, borrowed-param classification, tampered view surfaces the coherence violation). Gates: 145 cargo tests, oracle 132/132, check-delta 103/103, 33/27 sanitize, 3/3 differential, bench, clippy/fmt clean. |
| **Δ-5** | The position dimension of the coherence check (§6): per-statement drop anchors vs the front-end death spans. | **done**: every drop anchor is the anchored node's per-statement span; a `%1` drain drop must sit strictly after the death span (`anchor.1 > death.0`), `NO_SPAN` skipped. Landed with the `core.rs::expr` app-span fix (rebuilds extend to the last argument; head-only spans had ended every anchored statement before its own arguments — `linear_move.axi` `take b = val b` failed). 3 new unit tests (accept the take case, reject a span-collapsed anchor, the strict rule). Gates: 148 cargo tests, oracle 132/132, check-delta 103/103, 33/27 sanitize, 3/3 differential, bench, clippy/fmt clean. |
| F-1..F-4 | Per-field ownership (`%1` fields with own Δ — the strict-ANF form of the paper's constructor component typing); revisit `Field`-ret as owned (kills the Field-split rule); bridge to dependent sorts (§7-4 of memory-model-options.md). | **done** (F-1..F-4): docs/per-field-ownership.md. The Δ judgment tracks per-slot transfers (`Res.slot`, `Scope.split` slot-sets), `(Field·owned)` on selector reads, `(Drop·skip)` remainder-drop rule (`skip == transferred`), Detach skipped-slot binders, `Term::Drop` skip-field annotated dump. Lowering emits remainder drops (`case_arms`), skip-variant destructors (`axion_drop_T_skip_0`) generated + routed through backends. `transfers_heap_field` retired for the `%1` path (non-`%1` residual kept). Δ checker bug fixed: case-arm owned binders now populate `Scope.split` on the scrutinee, so `(Drop·skip)` remainder drops verify (112/112 check-delta). |

**Overfitting guard:** the Δ-1 checker must accept *exactly* the 132 fixtures —
rejecting any current valid program is a checker bug (the oracle is the test);
accepting an invalid one is caught by sanitize (27 leak-free) and differential.
The checker is *not* tuned per-fixture.

## 9. Open decisions

1. ~~**`UpdateRecord` ownership transfer**~~ — base consumed ⇒ result inherits its
   Δ. The `inplace` flag has the same Δ effect (it is a codegen choice). Needs
   a dedicated fixture (`land_tuple_upd.axi` covers the flat form; add an
   `inplace`-triggering one in Δ-1). **Δ-3 amendment**: the reclamation side
   now agrees — the base is marked escaped (`op_delta_effect` move), which
   removed the old `drop`-before-`update` the pipeline emitted.
   **Resolved**: `inplace_update.axi` covers the in-place form — `bump c = c
   { val = 99 }` mutates the `%1` Cell at its last live mention (Linear Elision,
   §2) with 1 alloc == 1 free; Δ agrees (`--emit delta`: `bump c = ok` — the
   inplace base escapes — `main` drops the returned record). Gated by the
   oracle (132/132) and check-delta (103/103).
2. **`CallClosure` moves all args** — closures have no mult signature today;
   moving all args is the conservative choice. If `%1` closure args ever appear,
   the rule becomes position-sensitive.
3. ~~**`RtCall`/`Ffi` borrow everything**~~ — **resolved in Δ-1 calibration**: they
   **move** their args. The reclamation analysis marks `RtCall`/`Ffi` args as
   escaped (`scan_op_escapes`), so the caller never frees them; a resource
   passed there dies in the callee. Revisit if the Buffer ABI gains owned args.
4. ~~**Generated functions**~~ — **resolved in Δ-1**: mono destructors
   (`axion_drop_*`) are verified with the *same* judgment and pass: the `%1`
   block parameter lazily enters Δ at its `axion_free`, the mixed-tag guard's
   two arms balance (the tag arm never frees, the payload arm frees), and the
   recursive payload drops are ordinary calls. Session state machines and their
   `$step` entries remain **trusted by construction** (scheduler nursery arena),
   skipped by name (`sess$*` / `*$step`).
5. ~~**`(Field-split)` permanence**~~ — **resolved by F-1..F-4 (per-field
   ownership, `docs/per-field-ownership.md`)**: `%1`-field extractions are now
   judged by `(Field·owned)` + `(Drop·skip)` remainder drops with per-slot
   `split` sets, and the `(Field-split)` rule is gone from `delta.rs`. The
   `land_deepdrop_safety` fixture deep-drops the `Tree` scrutinee in the `Leaf`
   arm; the non-`%1` residual (`transfers_heap_field` in `core.rs`) keeps the
   conservative shallow free for non-`%1` heap/poly payload aliases.
6. **Rejection fixtures** — the checker must not run on them in a way that
   changes exit codes (`set +o pipefail` semantics of dump-oracle must be
   preserved: content comparison, not exit-code comparison).
7. **View parameters are never pure borrows** — `drop n xs` returns cells
   shared with `xs` (the `n < 1` arm returns `Cons y ys`, reusing the input),
   so freeing the input at the call site double-frees the shared suffix with
   the result's destructor. The fix: `compute_borrow_args` auto-detects such
   "view" params (`destructures_and_embeds_recursive` — a destructured param whose
   recursive spine field is embedded into a constructor) and forces them to be
   **moved** at the call (the caller relinquishes the value —
   the reclamation side then never frees it), leaving the checker's Δ
   unchanged in spirit (`moves` for non-`%1` args is not linearity-tracked;
   later reads of the arg are still accepted). The result's destructor
   reclaims the shared suffix; cells the result never reaches (the dropped
   prefix) leak conservatively. `append`'s second list behaves the same way
   today — its `ys` param reaches a recursive call, so `occurs_nonborrow`
   already moves it; `take`/`map`/`filter`/`reverse` rebuild their cells and
   stay pure borrows. Regression: `drop_view.axi` (180), oracle 143/143,
   check-delta 114/114, sanitize 43 without corruption / 36 leak-free.

## 10. Relation to the Phase A′ anchors

The judgment reads Phase A′'s outputs *as types*: `owned_drop_ty` = the Δ₀ of a
function; `Op::ty` = the `produces` of a let; the destructor keys are the
`Some(k)` of deep drops. Phase A′ eliminated the *data* heuristics; Δ replaces
the *control* heuristics (liveness/borrow/transfer/alias) with a judgment —
the two halves of Auto-Drop become one proof, closing the plan's "High"
completion item (§7 of memory-model-options.md).
