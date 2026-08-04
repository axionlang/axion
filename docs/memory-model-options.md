# Design options — proving reclamation on a typeless Core

**Status:** proposal (pre-decision). **TL;DR:** Auto-Drop is not unsound about the
memory *model* — it is a "detective" reconstructing, on a blind `Core`, type facts
the compiler already proved and then threw away. The fix that best matches Axion's
philosophy is **late type erasure**: keep a typed `Core` IR, run Auto-Drop against
real types, and erase to the uniform-`i64` representation only at the backend
boundary — exactly the discipline Rust follows (types live on MIR; erasure happens
at MIR → LLVM). The annotation mechanism is not ad-hoc: it is the Δ-variable
typing of Linear Core (Mesquita & Toninho, "Lazy Linearity for a Core Functional
Language", POPL 2026), which makes linearity a typing judgment on the IR and whose
C.1–C.12 theorems prove every optimizer rewrite preserves it (§3.1). This document
compares that approach against the realistic
alternatives so a future reader can see what was weighed — and records the
recommended sequencing.

---

## 1. The reframe: a pipeline accident, not a runtime decision

Axion's runtime values are uniformly `i64`, heap objects carry a *size* header but
**no type tag** (`polymorphic-drop-plan.md` §1). That is a deliberate and good
runtime choice: one calling convention, lean codegen, no RTTI. It is not the
problem.

The problem is that the compiler **erases types at the wrong point in the
pipeline**:

```
Before (fragile):

  AST ──desugar (also erases types)──▶ Core IR (uniform i64)
                                            │
                                            ▼
                           Auto-Drop MUST RECONSTRUCT types by heuristics
                                            │
                                            ▼
                                        C / LLVM

After (robust / Rust-style):

  AST ──desugar──▶ Typed Core IR ──Auto-Drop reads ownership & destructors
                                   directly from the types──▶ Erased Core (i64)
                                                              │
                                                              ▼
                                                      C / LLVM
```

Erasure to `i64` is a *runtime* decision and it is correct; applying it *before*
the reclamation pass is what forced Auto-Drop into a guessing game. Moving erasure
to the very end un-mixes a sound runtime principle from a pipeline accident —
without changing a single byte of codegen output.

## 2. The problem in concrete terms: Auto-Drop on a blind Core

Every known Auto-Drop bug or leak traces back to a heuristic *reconstruction* of a
fact the typechecker had already computed:

| Heuristic | Where (`axionc/src/core.rs`) | What it guesses | Known casualty |
|---|---|---|---|
| `droppable_vars` | 3087 | is a value droppable at a death point | over-/under-frees; safe-leak cases |
| `is_heap_alloc` / `returns_owned_heap` | 3145 / 3141 | "heap or scalar?" — is this `i64` a pointer | the **extracted-field leak** (`docs/deep-recursion-plan.md:221`) |
| `collect_payload_aliases` + `op_mentions_any` | 3451 / 3275 | does a payload escape an arm | the **latent double-free** on incremental linear ADTs (`docs/deep-recursion-plan.md:211`) |
| `op_result_may_be_heap` | 3332 | is the arm's result heap-typed | the **poly-payload borrow/return double-free** (`docs/polymorphic-drop-plan.md:158`) |
| `dty` reconstruction — `collect_drop_types` / `collect_rhs_drop_types` / `build_all_drop_ty` | 2830 / 2861 / 2780 | the drop type of a value whose type is not in a signature | the **polymorphic container payload leak** (`docs/polymorphic-drop-plan.md:10`) |
| `field_is_heap` / `field_is_poly` / `named_field_is_heap` → `needs_deep_drop` | 515 / 524 / 549 / 426 | does a field own further heap? | the **Make-bound-local leak** (`polymorphic-drop-plan.md` Phase 4 gap) |

The double-free classes were not flaws in linearity; they were *mis-readings* of an
`i64` that the compiler had already proven was a pointer to `List`/`P`. Rust does
not have this bug class largely because the compiler never discards the fact.

## 3. The proposal: late type erasure (Phase A — typed Core)

Move the erasure point from `AST → Core` to `Core → backend`.

1. **Annotate the Core IR** — add a `Type` field to the `CoreFn`/bindings that hold
   an allocation, a call result, or a signature. Concretely these are the `Op::Make*`
   nodes (`core.rs:61–74`), owned `%1` parameters (already partially threaded through
   `build_all_drop_ty`), and call returns tracked by `heap_ret`.
2. **Migrate Auto-Drop to read the annotations.** Each of the guesses in §1 becomes a
   type query:
   - *heap-or-scalar?* → a direct `is_heap_allocated()`-style check on the annotated
     type, not inference from the `Op`.
   - *which destructor?* → the `DropWay` (`core.rs:2664`) is *proved* from the binding's
     type (`Deep(key)` from a `mono_key`-of-the-annotated-type, `Flat`, `None`), with
     no `dty` guessing (`core.rs:2830` deleted).
   - *who aliases the payload?* → ownership/lifetime facts that `%1`-linearity already
     pins; `collect_payload_aliases`/`op_mentions_any` shrink to a formality.
   - *does a local node own a payload?* → a `MakeX` binding carries its type, so the
     **Make-bound-local leak** (Phase 4 gap) never exists.
3. **Delete each heuristic as it is subsumed** — `op_result_may_be_heap` (3332),
   the `dty` reconstruction (`build_all_drop_ty`/`collect_drop_types`, 2780/2830), and
   the `field_is_*` guessing (515/524/549). This is **net-negative
   code**: the pass shrinks while soundness grows.

The design is *incremental* by construction: attach types, migrate one heuristic,
delete it, run ASan/LSan + oracle, repeat — exactly the shape of the `polymorphic-drop-plan.md` execution.

### 3.1 The formal backbone: Lazy Linearity (Mesquita & Toninho, POPL 2026)

The "Type field on bindings" from §3 is not an ad-hoc annotation — there is a
proven design for exactly this IR, in the same problem shape: "Lazy Linearity for
a Core Functional Language" (arXiv:2511.10361, `docs/lazy-linearity.md`), from the
GHC linear-types effort.

**The mechanism — Δ-variables.** Linear Core types every `let`-binding with a
*usage environment* Δ: the set of linear resources that evaluating the binding
consumes. A variable of type `[Δ]σ` is consumed exactly when Δ is consumed. This
is *semantic* linearity — it survives lazy evaluation and, more importantly for
Axion, *compiler rewrites*, because the invariant lives in the typing rather than
in the syntax.

**Why this is the concrete form of §3's annotation:**
- the annotation on a binding is `[Δ]σ` — the type *and* the ownership facts
  Auto-Drop needs, so §2's guesses become reads of the annotation;
- today Axion proves linearity **twice**, with two independent algorithms that must
  agree: `check.rs` (source-level consume counting, AX0001/AX0002/AX0004) and
  `core.rs` Auto-Drop (`insert_drops` core.rs:3213, `droppable_vars` core.rs:3087).
  Every double-free found so far is a *disagreement* between the two. A Δ-typed
  Core makes it **one judgment**: Auto-Drop's death point is "consume the binding's
  Δ", and the heuristics are deleted, not fixed.

**The rewrite-safety contract (the paper's payload for Axion).** The appendix
proves that the standard optimizer arsenal preserves linearity — theorems C.1–C.12
of `docs/lazy-linearity.md`: C.1 inlining; C.2 β-reduction; C.3 β-reduction with
sharing; C.4 case-of-case; C.5 let-floating/full-laziness; C.6 η-conversions; C.7
binder-swap; C.8 commuting lets.

Axion has exactly the planned rewrites this covers: the deep-recursion
defunctionalization pass (`docs/deep-recursion-plan.md` §4c), monomorphized
destructors, session state-machine lowering, TCO drop placement, and any future
inlining/let-floating. **Contract: every Core→Core pass ships with its C.n-style
preservation argument — or a Δ-typed CI validation — before it may reorder, copy,
or move a drop.**

**The perf rule (C.2/C.3).** β-reduction *with sharing* (allocation) is only
justified when the parameter is **unrestricted**; for a **linear** parameter,
substitute directly — sharing "would be counterproductive, and result in an
unnecessary heap allocation" (`docs/lazy-linearity.md:137`). Direct rule for
Axion's closure path (`eta_expand` core.rs:1281, `MakeClosure` core.rs:61) and for
future inlining: a `%1` parameter is substituted with **zero allocation**; only
`Many` parameters may be boxed/let-bound.

**Honest caveat.** Axion is strict, so the paper's lazy premise (a syntactic
occurrence does not necessarily consume) transfers here as *rewrite* preservation,
not thunks. But Axion's ANF is structurally the paper's `(Θ | e)` state semantics
with an explicit environment, so the Δ-subst / ω-subst lemmas port almost verbatim.

### 3.2 Lazy Linearity vs. the old plan — what Δ actually adds

The old plan (typed Core + mono + witness) says *"give the drop pass its types
back."* Lazy Linearity says *"and make linearity itself live in the typing."* The
second is not cosmetic — it adds exactly three things the old plan lacks:

**Safety:**
- **One judgment, not two.** The old plan still has `check.rs` (source-level
  linearity) and `core.rs` Auto-Drop (IR-level reclamation) as separate algorithms
  that must agree. Every double-free found this session was a disagreement between
  them. Δ-typing makes consumption a single typing judgment on the IR —
  `check.rs` and `insert_drops` become one pass. The old plan fixes the symptoms
  (heuristic guesses); Δ fixes the class.
- **Rewrites become provable.** The old plan's typed Core doesn't, by itself, stop
  a future inlining/case-of-case/let-floating pass from reordering a `free`.
  Δ-typing gives C.1–C.12: each rewrite carries a preservation proof (or a
  CI-checked Δ-validation). The old plan's answer was "re-verify with ASan each
  time"; the paper's is "the invariant survives by construction."
- **Soundness moves from measured to proved.** Old plan: ASan/LSan + GHC oracle
  (empirical). Δ-typing adds type preservation + progress (B.7–B.10) — the
  guarantee stops being a test suite and becomes a theorem. The GHC differential
  stays, but as corroboration, not the last line of defense.

**Performance:**
- **The sharing rule (C.2/C.3).** With Δ, sharing is only legal when Δ = `·`
  (unrestricted). A linear `%1` argument is substituted with **zero allocation**.
  The old plan doesn't give you this rule — it's a direct, static allocation
  eliminator (matters in the `alloc` benchmark, where arena already crushes
  malloc).
- **Unlocks the optimizer safely.** Strict languages win big from inlining,
  case-of-case, let-floating, full-laziness (the classic GHC speedups). The old
  plan makes each such pass a memory-safety risk; Δ makes them ships-with-proof —
  so Axion can actually take those perf levers without fear.
- **Exact death = earlier frees.** Δ consumption pinpoints death precisely, so
  Auto-Drop emits only the needed frees (same "fewer defensive instructions" win
  as the old plan, but now guaranteed exact, not best-effort).

### 3.3 Laziness in Axion today — and why Δ-typing benefits anyway

Today: zero laziness, by design — strict, call-by-value, ANF with explicit lets;
GC-free with drops at static death points (verified: the only suspension in the
codebase is a session `recv`, `interp.rs:877`). The paper's premise ("a syntactic
occurrence doesn't mean the resource runs, because of thunks") does not exist
here.

But the benefit survives, because the premise generalizes: the thing that breaks
syntactic linearity in GHC is thunks; the thing that breaks it in Axion is
rewrites — the planned defunctionalization pass, monomorphized destructors,
session state-machine lowering, TCO drop placement, future inlining. Δ-typing is
exactly the machinery that keeps linearity true after arbitrary IR surgery, which
is what a strict language with a growing optimizer needs. The paper even phrases
it as a coincidence-of-form: Axion's `(Θ | e)`-style ANF state is structurally
what Linear Core's semantics uses, so the Δ-subst / ω-subst lemmas port almost
verbatim.

One nuance: the paper's "β-with-sharing" rule is meaningless in strict Axion (no
thunks to share) — the transferable half is the forbidden direction: never let an
owned resource be duplicated; the permitted direction (allocate only for `Many`)
becomes a codegen rule for closures/inlining. And for the record: adopting
Δ-typing does not introduce laziness into Axion — it stays strict; only the
accounting is lazy.

### 3.4 Does it maintain the Axion philosophy?

Yes — on every stated pillar, and one honestly priced caveat:

| Pillar (README) | Status |
|---|---|
| Uniform `i64`, no GC, no type tag | ✅ unchanged — Δ lives in the compiler, erased before the backend (same as typed Core) |
| Release at static points, deterministic | ✅ **strengthened** — death points become exact (Δ consumption) instead of heuristic |
| No leaks (`allocs == frees`) | ✅ **strengthened** — provable, not just measured |
| Faithful linearity (GHC differential) | ✅ reinforced — it's the same linear-types family the paper validates against `linear-base` |
| Lean compiler | ⚠️ the only caveat — a full Linear Core is a real middle-end type system. But it's net-negative code (deletes the heuristics and the second analysis) and it's the pragmatic target, not the first step: the paper shows the end-state; Phase A′ narrow annotations remains the correct first cut, with Δ-typing as its principled completion |

The philosophical verdict is the same shape as the typed-Core argument, but
stronger: this isn't "borrowing Rust's discipline despite the philosophy" — it's
the formal proof layer that the philosophy's claims (no leaks, no double-frees,
static release) become theorems rather than sanitizer results. The only genuine
price is middle-end complexity, and it pays for itself by deleting code and by
unlocking the optimizer.

## 4. The honest trade-offs

| Dimension | Phase A — typed Core (annotated bindings) | Phase B — monomorphize owning generics |
|---|---|---|
| **Compiler complexity** | **Decreases (net-negative):** removes fragile heuristics above | **Increases:** instantiate generic functions that *own* (`%1`) a type parameter per `T` |
| **Compile time** | Negligible — the drop pass becomes a linear scan | Small rise, localized to the few owning polymorphic functions |
| **Binary size** | Zero impact | Slight (`code bloat` bounded by owning instantiations only) |
| **Soundness** | Full static guarantee: eliminates the double-free/leak classes above | Closes the last residual gap (generic functions that own, `polymorphic-drop-plan.md` Phase 5) |

**Why the compile-time hit of Phase B stays tiny here but is large in Rust:** Rust
monomorphizes essentially every generic by default. Axion's algorithms overwhelmingly
*borrow* data — borrowed generics never need a destructor, so they never need to be
specialized for reclamation. Only owning generic functions (e.g. a `drop_list`-shaped
`x : List a %1`) are candidates, and that set is small.

## 5. Impact on the runtime and on generated code

### Runtime: zero (or slightly positive)

Types are erased *before* the LLVM/C boundary, so the emitted machine code is
**byte-for-byte identical** to today: `i64` values, no vtable/type-tag/RTTI, no GC.
Nothing about the runtime model changes.

Two places the typed IR can *improve* the binary:

1. **Fewer defensive instructions.** The heuristics periodically emitted conservative
   frees/wraps to stay safe on ambiguous inputs; with exact types the compiler emits
   exactly and only the required destruction instructions.
2. **Better LLVM optimization when Phase B applies.** A monomorphized owning
   instance gives LLVM a concrete type to inline, unroll, and vectorize — more
   aggressive than the witness indirection. (This is the same reasoning that already
   produced the measured zero-cost `dispatch` benchmark via typeclass monomorphization.)

### Compiler: negligible

Annotating Core bindings (a reference/pointer per node) is negligible overhead
during desugaring, while Auto-Drop changes from a heuristic search to a linear scan
over known types — so Phase A can even reduce compile time.

## 6. The alternatives, and why they lose

The filename says "options"; this is the full comparison. The "who does the free"
column is what the runtime philosophy (uniform `i64`, no tag, no GC, release at
*static* points) insists on.

| Option | Who does the free | Runtime cost | Keeps "no tag / static points"? | Verdict |
|---|---|---|---|---|
| **A. Typed Core + monomorphization** (Rust) | compiler | none | ✅ | *reference — highest safety/effort ratio* |
| **A′. Narrow annotations** ("typed Core" only at allocation + drop sites, not every binding) | compiler | none | ✅ | ~80% of A's benefit at a much smaller diff — recommended *first cut* |
| **B. Drop-witness / destructor-table passing** (Swift value-witness, GHC) | compiler (+ a static `&fn`) | one static pointer per generic owning call — no field tags; payload stays `i64` | ✅ (no per-value tags) | keeps "compile-once body", no GC; the natural Phase B alternative if code bloat is measured as a problem |
| **C. Runtime type tag / fat header** (encode type in the allocation header) | runtime | memory per header + branch per free | ❌ reintroduces the type-at-runtime the design already dropped | against the stated philosophy |
| **D. Reference counting** (ARC) | runtime | refcount per heap object, nondeterministic release *timing* | ❌ breaks "release at static points" | rejects determinism promise |
| **E. Full GC** | runtime | collector, unpinned allocation, nondeterministic reclaim | ❌ "GC-free" is the thesis | rejected by design |
| **F. Region / bulk arena reclamation** | runtime (bulk reset) | complements A; doesn't remove the *need* for per-node drops in owned/deep structures | partial | a complement, **not** a replacement — Axion already ships arenas |
| **G. Keep the documented leak** (extracted fields, generic owners) | none | no UAF/double-free and still a leak | ✅ | honest `fallback` — "safe + leaky", weaker than the README's `allocs == frees` promise |

### Witness passing (B) — the detail to keep

The strongest **non-Rust** route for the residual *generic owning* case is
destructor passing:

```
drop_list[A](x : List A %1):
  takes a static pointer to A's destructor (e.g. axion_drop_A) from the
  caller or a drop table, so a SINGLE compiled body can free each A payload.
```

Why it exists here: it **keeps one compiled body** for the generic function (no
code bloat, no per-instantiation IR), and it stays GC-free and field-tag-free — the
witness is only a *compile-time-known static pointer into the drop table*, never a
per-value tag. The cost is one small indirection per generic owning drop — a
runtime branch only where the type was genuinely unknown at compile time.

**Choose B (witness) over monomorphization when:**
- a measured code-bloat spike from owning instantiations threatens a binary-size
  budget — the same pressure that made Rust weigh `#[inline]`/`no_mangle` choices
  carefully; or
- you want one diagnostic body to debug instead of a family of copies.

**Otherwise choose monomorphization (Phase B):** it is consistent with what Axion
already does — monomorphized destructors (`gen_mono_destructors`, `core.rs:2706`)
and zero-cost typeclass dispatch (README) — so mono is the "native" path, and
witness B is the escape hatch when mono's cost shows up on a specific target.

## 7. Recommended execution sequence

1. **Phase A′ — narrow annotations first.** ✅ **done** — attach the `data`-type
   name (the drop-type part of the full annotation) to the allocation/return/
   `%1`-signature nodes (`Make*`, call results, `owned_drop_ty` on `CoreFn`).
   The backends stay untouched (erasure before codegen).
2. **Migrate Auto-Drop bottom-up and delete the heuristics as they are subsumed:**
   ✅ **done** (`is_heap_alloc`, `returns_owned_heap`, `heap_ret`, `enum_con_names`,
   the `build_all_drop_ty` signature re-read), each step verified by
   `scripts/sanitize.sh` (ASan/LSan: `allocs == frees`, no double-free),
   `scripts/differential.sh` (GHC oracle: same verdicts, zero semantic drift)
   and `scripts/dump-oracle.sh` (line-sorted `--emit core` snapshot) — the drop
   path is the most memory-safety-critical code in the compiler.

3. **Phase B — close the generic-owning corner.** Once the typed IR exists, the
   choice is cheap to try in *either* direction:
   - monomorphize the owning generic function (consistent with destructor /
     typeclass monomorphization), **or**
   - witness-pass the destructor pointer (Phase B-fallback) the moment a
     code-bloat spike matters.
   The small number of owning-generics (most generics borrow and thus never drop)
   keeps both options cheap; the decision can be made on measured data.
4. **Future bridge to the paper's dependent sorts.** The same annotated-type
   infrastructure that powers drop is what a *classical/linear (parameter/resource)
   sort* and indexed types will later consume.

## 8. Gates and non-goals

**Gates (same as every feature shipped):**
- `scripts/sanitize.sh` — ASan/LSan clean on `--dev` and `--release`, leak-free
  fixtures (`allocs == frees`) in the gate;
- `scripts/differential.sh` — identical verdicts to the GHC oracle;
- `scripts/bench.sh` — no common-case regression (this must not change the `alloc`
  or `fib` numbers);
- the rolling delete of each heuristic must land with the fixture that formerly
  exercised it.

**Non-goals — what the typed Core must NOT become:**
- no type tags / RTTI at runtime, no fat headers — erasure still happens before LLVM;
- no GC, no refcount adoption — full reclamation stays deterministic and static-point;
- no runtime change whatsoever for programs that don't hit Phase B;
- no new IR: the typed Core is the *same* Core shape with annotations — both
  backends (`codegen.rs`/`llvm.rs`) continue unchanged.

## 9. Decision needed (for a future reader)

An open choice recorded for whoever picks this up:

- **Recommended default:** Phase **A′ (narrow annotations)** now, as the smallest
  step that converts Auto-Drop from "proof from reconstructed facts" into "read
  correctness off the types"; then **Phase B via monomorphization** (consistent with
  typeclass/destructor mono), falling back to **witness passing** only on a measured
  code-bloat/spike.
- Precisely the point of this document: the typed-IR move is *net-negative*
  complexity — it removes safety-critical guessing code rather than adding machinery;
  the only real price tag in the whole space is Phase B's bounded compiler weight, and
  even that has the witness fallback.

## 10. Effort and scope — does it touch the core principle, and how much code?

### 10.1 The core principle is untouched

The plan does not touch the runtime, the ABI, or the backends:

- Uniform `i64` ABI, erasure, no type tags, strictness, GC-free — all unchanged
  (an explicit non-goal, §8);
- `codegen.rs` and `llvm.rs` consume `Term`/`CoreFn`; the annotations are erased
  before the backend.

The change is entirely in the *middle-end*: from "untyped Core + the analysis
reconstructs the facts" to "annotated Core + the analysis reads the facts".
Internal to the compiler, invisible to the user.

### 10.2 How much code is redone? Mostly deleted.

The good news: the type information already exists at `lower()` time
(`core.rs:2180`):

- `f.sig: Option<Type>` on every function — **already used** for `heap_ret`
  (`core.rs:2207`) and `owned_params` (`%1` arrows);
- constructor fields already carry types (`f.ty`, `core.rs:407`);
- `mult` (`%1`/`Many`) is already parsed in `Type::Arrow`.

What is missing is *structure, not inference*: plumbing those types onto the Core
nodes (`Make*`, call results, sigs, `Drop` — today `Term::Drop(String,
Option<String>, …)` holds only a type *name* reconstructed by the heuristics
`build_all_drop_ty`/`collect_drop_types`, `core.rs:2780–2861`). The real estimate:

| Part | Situation | Effort | Verdict |
|---|---|---|---|
| **Annotate Core nodes + thread types from the AST** | Done (Phase A′): `MakeCon`/`MakeRecord`/`CallDirect` carry the `data`-type name from lowering (`ty: Option<String>`), and each `CoreFn` carries the owned-`%1`-param drop keys (`owned_drop_ty`) — resolved at `lower()` time, no reconstruction | Low | ✅ landed, gates green |
| **Heuristics** (`core.rs:2454–3370`, ~900 lines) | Deleted as subsumed: `is_heap_alloc`, `returns_owned_heap`, `heap_ret` (build + threading), `enum_con_names`, and the signature re-read in `build_all_drop_ty` (~130 lines; the rest of the range is structural escape/alias/transfer logic, kept by design) | Negative | ✅ net-negative — precisely the point of this document |
| **Backends, runtime, surface checks** | Untouched (annotation erased before codegen; `codegen.rs`/`llvm.rs` changes are mechanical pattern updates) | Zero | ✅ nothing to do |
| **Δ validator (full Linear Core)** | New, heavy (~1–2k lines) | High | ⚠️ the final *completion*, not step 1 — next |

Confirmed: `check.rs` already emits `DropPoint`s (`check.rs:1292`), but they only
feed a debug `print_drops` (`main.rs:864`) — the real `insert_drops` (`core.rs:3213`)
does its own analysis. That is exactly the "dual analysis" Δ unifies.

**Phase A′ status (measured):** the drop analysis (droppable set, drop types,
deep-drop safety) now *reads* the lowering annotations — nothing re-derives an
allocation decision from the source types at analysis time. The remaining
`RecordInfo` uses are static field/layout info (destructor generation, the
`Field` scalar-proof clause, field-transfer on `case`) by design. Verified by:
`scripts/dump-oracle.sh` (line-sorted `--emit core` snapshot, 132 fixtures —
raw dumps are nondeterministic in *order* only), `scripts/sanitize.sh`
(33 fixtures ASan-clean, 27 proven leak-free, incl. the 5 `land_*` landing
fixtures that lock each deleted heuristic's behavior), `scripts/differential.sh`
(3/3 GHC verdicts), `scripts/bench.sh` (all kernels agree).