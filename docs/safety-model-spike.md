# Design spike — the reclamation safety model: whack-a-mole vs. a rock-solid floor

**Status:** DECISION SPIKE (no code). Written after a session that closed four *verifier-blind*
double-frees/UAFs in the tuple / record-field reclamation area. The question this document exists
to answer is not "what is the next fix" but "**is the current architecture the right one, and if
not, what is the lean, rock-solid alternative — and what does it cost?**"

Companion docs: [`call-site-ownership.md`](call-site-ownership.md),
[`per-field-ownership.md`](per-field-ownership.md), [`delta-design.md`](delta-design.md).
Memory: `axion-drop-verifier`, `axion-conditional-param-return-uaf`, `axion-irreproachability-roadmap`.

## 1. The pattern we need to be honest about

In one session, hand-probing plus the differential fuzzer surfaced **four** reclamation bugs:

| Shape | Symptom | `--emit verify` said |
|---|---|---|
| grab-via-case getter reused (String) | native double-free | **clean** |
| conditional tuple `ret_alias` reuse (P3) | native double-free | **clean** |
| nested-tuple case-extraction escape | native UAF | **clean** |
| Integer grab-via-case reuse | native double-free | **clean** |

The common factor is the alarming one: **the drop-balance verifier (`AX0910`), which is presented
as the compile-time soundness guarantee, reported "clean" on every one of them while AddressSanitizer
aborted.** `AX0910` is therefore not the guarantee it looks like — it is "safe *where the verifier
can see*," and we keep discovering places it cannot.

Each fix was individually sound and fully validated. But structurally they *accrete*: `core::case_arms`
now carries ~6 interacting reclamation branches (notion-2 borrowed-dead, tuple move-out,
skip-destructors, grab-via-case, mixed-conditional, deep-vs-shell), and `verify::compute_summaries`
runs pure / elem / ret_alias / frees_heap / poly passes. A system that is "hard as a rock" does not
have twenty special cases, each a candidate for the next blind spot.

The Integer-in-data investigation (this session) is the clearest tell: there is a **genuine
ambiguity in the model** — a heap field can be owned by its *extractor* or by its *record's
destructor*, and no local rule picks correctly for all uses — so the obvious "fix" (track Integer in
`con_drop_slots`) fixes one shape and breaks another. That is not a missing patch; it is the model
being under-specified at its core.

## 2. Root cause

Axión does not *state* ownership in the source; it **infers** it (who frees, and when) via heuristics
in `core.rs`, then **re-checks** the result with a post-hoc verifier. Both halves are incomplete:

- the **inference** is incomplete → it emits unsound drops in the corners (the four bugs);
- the **verifier** is incomplete → it fails to catch those unsound drops (verifier-blind).

Bugs live in the gap between the two — and in the further gap between the real verifier and the
machine-checked Lean model, which proves the *model* sound, not the *implementation*. Every bug this
session was an implementation-vs-model divergence that the model would have rejected.

The invariant we actually want is simple to *state*:

> **Every heap allocation has exactly one owner and is freed exactly once; an alias (a field, an
> element, a returned parameter) may be read while its owner is live, but may not be freed or
> consumed-as-owned unless ownership was explicitly transferred (move) or duplicated (copy).**

The whole difficulty is *reconstructing* that invariant after the fact instead of *enforcing* it.

## 3. The options

### Option A — Conservative-complete floor + explicit `copy` (simplest; a copy tax)

One uniform rule in the verifier, **no per-type gates**: every heap interior (field / element /
param-return) is an alias of its owner; *consuming or dropping an alias while the owner is live is
rejected (`AX0910`)*. The programmer's escape hatch is an explicit `copy` (and borrow). Inference is
kept only as far as it is provably sound; anything uncertain is **rejected, never emitted**.

- **Safety:** rock-solid. With no gates (`Integer excluded`, `nested case not followed`,
  `primitive + not checked` — the three places the bugs hid), there is nowhere for a blind spot to
  live. `AX0910` becomes a theorem, not a hope.
- **Performance:** a real cost in one spot — field *move-out from a consumed container*
  (`map getV`) would need an explicit `copy` per element, which is O(n) bignum/string copies the
  current untracked model avoids. Hot numeric loops are unaffected (they do not extract-and-escape
  heap fields).
- **Ergonomics:** the heaviest. Common idioms gain explicit `copy`s.
- **Complexity:** lowest — deletes special cases.

### Option B — One uniform move-vs-copy rule driven by container liveness (rock-solid *and* fast)

The "deep lever" reframed as a **single** rule rather than a pile of cases. Extracting a heap field:

- container **consumed** at the extraction site → the field **moves** out (zero-copy; the
  destructor skips the moved slot). `map getV` (map consumes its list) stays zero-copy.
- container **borrowed** and the field is only **read** → the field is a **borrow** (zero-copy;
  owner frees once). Read-only getters, even reused, stay zero-copy.
- container **borrowed** and the field **escapes / is duplicated** → **copy** (auto-inserted where
  inference is sure; otherwise rejected asking for an explicit `copy`). This is the only taxed case
  and it is rare.

- **Safety:** rock-solid (same complete floor as A; the rule *decides* move/borrow/copy, the
  verifier *checks* it).
- **Performance:** keeps today's zero-copy for the common cases; copies only on borrowed-escape.
- **Ergonomics:** near today's; the one behavioral change is failure-mode (below).
- **Complexity:** moderate — one coherent rule (container-liveness at each extraction site)
  *replacing* the six special cases. Conceptually simpler than today; real work to land.

### Option C — Status quo (keep accreting inference special-cases) — **not recommended**

Each new corner is a new branch and a new potential blind spot. Individually sound, collectively
making "rock-solid" less true over time.

### Option B, realized — an explicit Ownership IR (the keystone)

Option B names the *rule*; this is its *representation*, and it is what structurally forbids
blind spots. The root cause (§2) is that the verifier *re-derives* ownership with the same
heuristics the compiler used — so it validates the compiler's assumptions instead of checking an
independent invariant. The fix is to make the move/borrow/copy **decision a first-class IR node**
and reduce the verifier to a *checker* of those nodes.

Every heap-field extraction (a `case` binder, a projection) lowers to exactly one tagged op:

```
ExtractOp ::= MoveOut(slot)      -- ownership transfers out; the container's destructor SKIPS slot
            | BorrowRef(slot)    -- an alias; the container still owns it and frees it once
            | ExplicitCopy(slot) -- a fresh owned duplicate (axion_copy_* / strAppend x "" / bignum_copy)
```

- **`core.rs` (inference) is the only thing that CHOOSES the tag**, via the container-liveness rule:
  container dead at the site → `MoveOut`; container live & read-only → `BorrowRef`; container live &
  the value escapes/duplicates → `ExplicitCopy` (auto-inserted when inference is sure, else a
  rejection asking for a source `copy`).
- **`AX0910` (the verifier) has ZERO knowledge of how the tag was chosen.** It checks only that the
  tags obey linear scope: a `MoveOut(slot)` is sound iff the container is provably not used after
  this point AND no other extraction already moved `slot`; a `BorrowRef` result is never freed; an
  `ExplicitCopy` result is independently owned. Emit a `MoveOut` on a container referenced later and
  the verifier rejects *instantly* — it cannot "guess along" with the compiler, because the decision
  is data it inspects, not logic it re-runs.
- **The Lean bridge (§5) becomes near-tautological.** State the operational semantics over the same
  three primitives; verdict-equivalence is then structural rather than a shape-by-shape coincidence.

This is the decoupling that converts "safe where the verifier can see" into "the verifier cannot be
blind, because there is nothing left to infer." The three historical blind spots (`Integer excluded`,
`nested case not followed`, `primitive + not checked`) were all places the *re-derivation* lacked a
case; with an explicit tag there is no re-derivation to be incomplete.

### Honest scoping of Option B (what the headline claims gloss)

Three corrections to keep the effort estimate and sequencing truthful:

1. **The failure-mode inversion (§4) is NOT a free-standing "flip one branch."** Today there is no
   single "uncertain" signal to flip — uncertainty is distributed, and the *wrong* decisions look
   confident. A clean reject-on-uncertain only exists once extraction is an explicit tag, where
   "cannot assign a sound tag" is a well-defined, local reject point. So §4 is a *property of the
   tag-assignment pass*, delivered WITH the IR — not a cheap pre-step. (Narrow fail-closed points,
   e.g. a reused param-return over an uncopyable type, can reject today; that is not the general §4.)
2. **"Six heuristics → one rule" holds at the DECISION layer, not the MECHANISM layer.** The
   container-liveness rule replaces the six *decision* branches in `case_arms`; the machinery they
   drive (skip-destructors, shell-free-last ordering, tuple-key arity, poly-element gating) is *how a
   partial free is emitted* and stays — now *driven by* the explicit tag instead of re-inferred.
   Expect to delete decision logic, not the emit mechanics.
3. **"One liveness check" is easy intra-procedurally, hard inter-procedurally.** Within a function,
   container liveness is a local dataflow. But the biting bugs (P3's `go`/`pickT`, Integer
   grab-reuse) are interprocedural — "does the callee consume or borrow the container I pass it?" —
   which needs per-function ownership summaries, i.e. the call-site-ownership analysis deferred all
   along. B's core *is* that summary machinery; tractable, not a one-liner.

## 4. The failure-mode inversion (a property of the tag pass, not a free-standing step)

Independent of A vs B, the single highest-value change is to flip what inference does when it is
**uncertain**:

> today: uncertain → emit code → silent double-free.  proposed: uncertain → **reject** ("add a
> `copy` here") → never unsound.

This converts the entire bug *class* from "ships and crashes" to "does not compile." The new
diagnostic needs a fresh code — **`AX0913`** (`AX0910`/`0911`/`0912` are taken: corruption / leak /
element-alias) — e.g. *"cannot infer ownership transfer for extracted field `x`; pass the container
by move or insert an explicit `copy`."* Per the scoping note above, the *general* form of this
inversion is delivered as the failure mode of the tag-assignment pass, not as a standalone edit.

## 5. Prove there are no blind spots left — the faithfulness bridge

You already have a Lean proof that the *model* is sound and a bridge checking
`model-verdict == real-verifier-verdict` on 8 canonical shapes. Extend that bridge to the **whole
corpus** (already the "NEXT" item in `axion-irreproachability-roadmap`). Every bug this session was a
model/implementation divergence; a whole-corpus bridge turns such divergences into **proof failures
at build time** instead of ASan crashes in production. This is the forcing function that keeps either
option honest.

Calibration: the achievable, high-value target is **whole-corpus verdict-equivalence**
(`model-verdict == real-verifier-verdict` over `tests/fixtures` + `examples` + fuzz seeds), wired
into CI. A true 1:1 embedding of the real Rust verifier into the Lean operational semantics is
CompCert-scale — the north star to name, not a step to scope. The explicit Ownership IR (§3) is what
makes even verdict-equivalence cheap: both sides reason over the same `ExtractOp` primitives.

## 6. Tradeoff matrix

| | A: conservative floor | B: move-vs-copy rule | C: status quo |
|---|---|---|---|
| Safety (is `AX0910` a theorem?) | **yes** | **yes** | no (empirical) |
| Runtime perf | copy tax on field-extract | **≈ today** | ≈ today |
| Ergonomics | heaviest | near today | best (until a bug) |
| Implementation complexity | **lowest** | moderate (one rule) | grows each session |
| Lines deleted vs added | deletes cases | replaces cases | adds cases |
| Philosophy ("lean, provably sound") | strong | **strong** | drifting |
| Risk of the next verifier-blind bug | none by construction | none by construction | **ongoing** |

## 7. Recommendation & sequencing

Target architecture: **Option B, realized as the explicit Ownership IR** (§3) — verifier as a pure
checker of `ExtractOp` tags, failure-mode = reject, bridge extended corpus-wide. Chosen *if* Axión's
identity is "lean, provably-safe, lighter than Rust" (the stated north star): B keeps the performance
and most of the ergonomics while making `AX0910` a theorem, and it *shrinks* the model.

Sequencing, corrected for the §3 honesty points (note §4 is folded into Step 1, not before it):

1. **ExtractOp IR + tag-assignment pass**, with the reject-on-can't-tag failure mode built in
   (this *is* §4, done properly — `AX0913`). Lower every heap-field extraction to
   `MoveOut`/`BorrowRef`/`ExplicitCopy`. Start with the container-liveness decision done
   *intra-procedurally*; emit `AX0913` where the local pass cannot prove a sound tag.
   **Started — read-only slice landed:** `core::classify_extractions` + `--emit extract-tags`
   tag every `Con` heap-field `case`-extraction by the intra rule (type-based heap test, so
   `Integer` is visible — it was the blind spot), non-gating. **Corpus measurement (285 files, 129
   with extractions, 889 sites): MoveOut 317 / BorrowRef 511 / ExplicitCopy 61; 627 (71%) the intra
   rule tags confidently, 262 (29%) hinge on a callee** → that 29% is precisely the work the Step-3
   interprocedural summary buys. Two refinements this slice forced: the heap test must be
   type-based (not `con_drop_slots`, which hides `Integer`), and a bare-returned field from a
   borrowed container is a grab (`BorrowRef`), not a copy. Remaining to gate: tuple scrutinees,
   then the tag-checker (Step 2).
2. **Refactor `AX0910` to check tags only** — co-designed with Step 1 so the verifier inspects the
   `ExtractOp` nodes rather than re-deriving ownership. This is the decoupling that kills the echo
   chamber.
   **Started — tuple extension + second-opinion checker landed:** `classify_extractions` now also
   tags tuple scrutinees (element types recovered from the arity-encoded mono-key; local-tuple
   scrutinees are honest under-coverage, never a wrong tag). `core::tag_check` + `--emit tag-check`
   is the second opinion: from a TYPE-based tag borrow-return summary it reports any site that frees
   the same `(scrutinee, getter)` field **≥2 times** — the real double-free, so a sound single
   extraction is never flagged. Proven on the corpus (tests/tag_check.rs): **0 false positives over
   the whole ASan-clean corpus** (faithful) AND it **flags the Integer grab-via-case reuse that
   `--emit verify` reports clean** (strictly stronger — the drop_slots gate hid the Integer field;
   the type-based tags do not). Still non-gating. Remaining before the flip: realize the tags in
   lowering (so the checker can gate as the sole authority, Step 3).
3. **Interprocedural liveness summaries** — add the per-function "consumes vs borrows its container
   arg" summary so the taxed cases (P3, grab-reuse) get `MoveOut`/`ExplicitCopy` across call
   boundaries. Retire the `case_arms` *decision* branches as each is subsumed (keep the emit
   mechanics). This is the bulk of the work and the real "deep lever."
4. **Whole-corpus faithfulness bridge in CI (§5)** — verdict-equivalence over fixtures + examples +
   fuzz, so the arc ends in a guarantee, not another round of whack-a-mole.

**Do not land further per-case fixes** meanwhile. The Integer-grab-reuse residual and the
nested-`case` verifier-net gap are *symptoms*; fixing them one-by-one is Option C. They are subsumed
by Steps 1–3.

The decision that unlocks everything is the **identity call** in §3's framing: are we willing to let
the compiler **reject** an ambiguous program and ask for an explicit `copy`, in exchange for a
soundness *guarantee*? If yes → B. If the priority is that every currently-compiling program keeps
compiling untouched → then we are committed to C's inference-completeness treadmill, and the honest
mitigation is at least §4 + §5 so the treadmill cannot ship a double-free.

## 8. What this is NOT

- Not GC and not mandatory refcounting — ownership stays static and deterministic.
- Not a full Rust borrow checker — immutability means no mutation/aliasing-XOR reasoning; the only
  question is frees, which is why a *lighter* discipline can still be complete.
- Not a rewrite of the backends or runtime — this is front-of-`core` ownership + the verifier.
