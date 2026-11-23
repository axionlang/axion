Roadmap: closing the gaps to Idris 2/ATS, Austral and Mojo — safely

Context

After comparing Axion with linear/uniqueness-typed languages, three gaps remained: what you can
PROVE (Idris 2/ATS), SIMPLICITY/AUDITABILITY of the rules (Austral), and raw PERFORMANCE range
(Mojo). The user asks how to close them without weakening safety. This is a roadmap; each track
starts with one concrete, gated milestone.

The safety rule every step follows (already Axion's architecture)

Inference may get smarter; only the CHECKER is trusted. core.rs (17k lines of ownership
inference) is untrusted; verify.rs (2.6k) + the Lean model (metatheory/) are the judge.
So every feature: (1) its output passes the existing verifier, (2) any NEW trusted code gets a
Lean model + a test tying code to model (the AxionBce.lean + bce.rs guard_matches_the_model
pattern), (3) a fuzz generator (scripts/fuzz.py --only …), (4) leak-gated fixtures, (5) the
bench gate. Fail-safe default: if a proof isn't found, keep the runtime check — worst case is
slower, never unsound.

Track B (first) — Austral-level auditability

Highest value per effort, and it makes A and C safer.
1. Normative ownership spec docs/spec.md: numbered rules (~1–2 pages, Austral-style), each
   with the fixture that pins it; every AX0001/0002/0004/0007/0910/0911/0912 message cites its
   rule number (diag.rs, docs/error-codes.md).
2. Widen the M2 bridge (metatheory/model-trace.sh, axionc/src/model_trace.rs): executable
   checkers for the AxionAlias and AxionKey slices so more of the corpus is in-fragment
   (today 426 / 1220 functions). Target ≥ 80 %.
3. Shrink the conservative rejections that users hit only via changes the verifier judges:
   fst/snd borrow instead of consume (the Rule B case found earlier) is the first.
4. North star (later): extract the verifier from the Lean model (GUARANTEE.md §6).

Track A — provable properties without full dependent types

Refinements over decidable integer arithmetic, not dependent types (keeps inference and errors
Haskell-simple; avoids an SMT solver in the trusted base).
1. Index refinements {i : Int | 0 <= i < len a} on params/lets, checked by a small
   Presburger/Fourier–Motzkin decision procedure in Rust that emits a certificate; a tiny
   certificate checker is the only trusted part, modeled in Lean. Payoff: proven bounds-check
   removal beyond bce.rs loop versioning (gauss 133 → ~100, ternmv 120).
2. Totality: structural-termination check (total annotation), so a proof function can't
   loop — Idris's other key guarantee.
3. Contracts requires/ensures on Int/length facts: discharged statically when the
   procedure proves them, else a runtime check; --certified reports which remain dynamic.

Track C — performance range

1. Refinement-driven BCE (A.1) — closes the measured gaps first.
2. SIMD value types (F64x4, I32x8, …): plain values, no heap, so safety is trivial; lower
   to LLVM vector IR and Cranelift SIMD, lanes modeled in the interpreter; extend bench/simd.
3. Safe data parallelism: parFor over an array split LINEARLY into disjoint slices
   (data-race freedom from linearity, like ATS/Austral), on the existing M:N scheduler.

Recommended order

B.1 → B.3 (fst/snd) → B.2 → A.1 (+C.1) → C.2 → A.2 → C.3 → A.3.
Start: B.1 spec + rule numbers in diagnostics, then B.3 fst/snd borrow.

Verification (per milestone)

Tiered gate (fmt, clippy, cargo test, oracle, verify-gate, sanitize, fuzz), model-trace/bridge
for verifier-adjacent work, Lean metatheory/check.sh for new models, scripts/bench.sh --check
for perf work. Commits only when the user asks.

Improving Axion safely: a roadmap for the three gaps

The rule that keeps it safe: Axion already separates what's trusted from what isn't. The ownership inference in core.rs (about 17k lines) can be wrong without breaking safety. Only the checker (verify.rs, about 2.6k lines) and its Lean model decide what is accepted. Every improvement keeps that split:
- what the new feature produces must still pass the existing checker;
- any new trusted code gets a Lean model and a test tying the code to it, as AxionBce.lean and bce.rs already do;
- each feature gets a fuzz generator, leak-checked test programs and the benchmark gate;
- if a proof isn't found, the runtime check stays. The worst outcome is slower code, never unsound code.

1. Simpler, auditable rules, like Austral (do this first)

It's the cheapest of the three, and it makes the other two safer.
- Short written spec (docs/spec.md): one or two pages of numbered ownership rules, each pinned by a test program. Every ownership error message (AX0001/0002/0004/0007/0910/0911/0912) would cite its rule number. A user gets the checkable rules Austral offers without having to write every free.
- Prove more of the real programs: today the Lean model is checked against the real checker's verdict on 426 of the 1220 functions in the test corpus. Adding the alias and drop-key parts of the model would bring that to 80% or more.
- Fewer conservative rejections, judged by the checker: start with making fst/snd borrow their argument, which removes the most common AX0001 surprise.
- Long term: generate verify.rs from the Lean model, so the checker itself is no longer trusted code.

2. Proving more, toward Idris 2 / ATS, without full dependent types

- Refinement types for integers: for example, {i : Int | 0 <= i < len a}.
  - A small decision procedure for integer arithmetic proves them and emits a certificate.
  - Only a tiny certificate checker is trusted, and it gets a Lean model.
  - No SMT solver enters the trusted code.
- Totality checking: a total annotation, so a function used as a proof can't loop forever.
- requires/ensures contracts: proven at compile time when possible, otherwise checked at run time. --certified would report which ones stay as runtime checks.

3. Performance range, toward Mojo

- Bounds-check removal from refinements: this fixes the measured gaps first (gauss 133, ternmv 120).
- SIMD vector types such as F64x4 and I32x8:
  - They are plain values with no heap, so they pose no safety risk.
  - They would compile to LLVM and Cranelift vector instructions, and the interpreter would model them.
- Safe parallel loops: a parFor that splits an array into disjoint pieces, each used once, so data races are impossible by construction. It would run on the existing scheduler.

Recommended order: written spec → fst/snd borrow → more of the corpus under the Lean model → integer refinements with bounds-check removal → SIMD types → totality → parallel loops → contracts.
