# Design plan — consolidate the linearity judgment onto the drop-balance verifier

**Status:** proposal (pre-implementation). **Goal:** realize `delta-design.md`'s
"collapse the dual analysis into one proven judgment" — but via the *newer, sound*
implementation (`verify.rs`, the drop-balance verifier) rather than the older
`delta.rs` Δ judgment (`check_all`) that has fallen behind the reclamation. Net
result: **one** soundness judgment, ~500 fewer lines, and the currently-advisory Δ
CI gate becomes a blocking, in-sync proof again.

## 1. Why this, not "resurrect `delta.rs`"

`delta-design.md` phases Δ-1..Δ-5 + F-1..F-4 are all *implemented* — the Δ judgment
(`delta.rs::check_all`) was a mature realization of the paper's strict-ANF rules. But
the reclamation (`core.rs::insert_drops`) kept advancing — tuple per-element drops,
multi-param field keys (`Either$Int$Int`), closure-capture borrows, view auto-move,
notion-2 — and `check_all` was not kept in sync. It now **false-positives on ~26
fixtures** (six root-cause classes: tuple-field extraction, heap-param drops, generic
vs. mono keys, record-update skips, closure captures, `Unsupported op` on
parmap/session), which is why the `delta` job's Δ step is currently `continue-on-error`
(advisory).

Meanwhile `verify.rs` (the drop-balance verifier, AX0910/AX0911, default-on hard gate)
is the **in-sync, 0-false-positive, ASan-cross-checked** soundness proof over the same
final Core, using the same `delta::op_delta_effect` authority. This session it gained a
**drop-key cross-check** (a value's reclaimer must match its type) and **param-type
threading** — strictly *more* than `check_all` proves.

So the two analyses overlap, `verify.rs` is the better one, and keeping both is exactly
the drift-prone duplication the design set out to remove. **Path B makes `verify.rs`
the single judgment and retires `check_all`.**

## 2. What is shared, unique, and redundant

| Component (`delta.rs` unless noted) | Role | Fate |
|---|---|---|
| `op_delta_effect` | the single multiplicity axiom table (used by `verify.rs`, `core.rs insert_drops`, the dump) | **KEEP** — foundational, already the collapse the design wanted |
| `dump_annotated` / `--emit core` `Δ{}`·`moves{}`·`makes` | the annotated dump the oracle snapshots | **KEEP** — built on `op_delta_effect`, independent of `check_all` |
| `dump_delta` / `--emit delta` | per-function debug verdicts | KEEP or trim (debug-only) |
| **`check_all` (the Δ judgment)** | proves no double-free/UAF/leak over the Core (the `--check-delta` gate) | **RETIRE** — redundant with `verify.rs`, and 26 fixtures behind |
| `check_drop_coherence` | cross-checks `check.rs` DropPoints (front-end liveness) ↔ Core classification/anchors | **DECIDE** (§ Step 4) — the one guarantee `verify.rs` does not replicate (it never sees `check.rs`) |
| `verify.rs::verify` | the sound corruption+leak proof over the Core (`--emit verify`, AX0910/AX0911) | **PROMOTE** to the sole judgment / blocking Δ gate |

`check.rs` DropPoints "decide nothing at runtime … consumed only by the debug
`print_drops`" (delta-design §6) — a vestigial/debug analysis. That bears on Step 4.

## 3. Steps (each behavior-identical, same gate discipline)

Gates run at every step (the project's standard): `./scripts/dump-oracle.sh` (now
`LC_ALL=C`), `AXION_CLANG=clang ./scripts/sanitize.sh` (ASan/LSan), `./scripts/
differential.sh` (GHC oracle), `cargo test`, `cargo clippy --all-targets -- -D warnings`,
`(cd axionc && cargo fmt --check)`, and — after pushing — the CI run via `gh`.

### Step 0 — Subsumption study (prove nothing is lost)
**Deliverable:** a short table/appendix proving `verify.rs`'s guarantees ⊇ `check_all`'s
for the Core proof, and an evidence run.
- Both prove no double-free / UAF / silent-leak over the *final* Core via the same
  `op_delta_effect`; `verify.rs` additionally does the drop-key/type cross-check and is
  ASan-cross-checked + 0-FP. Enumerate `check_all`'s rules (§5 of `delta-design.md`) and
  map each to the `verify.rs` mechanism.
- **Evidence:** over the whole corpus, `--emit verify` reports **0 corruption**
  (already true — `verifier_reports_no_corruption_over_all_fixtures`), while
  `--check-delta` reports 26 *false* positives. Add a **tamper battery**: a set of
  deliberately-broken Core mutations (double-free, UAF, wrong-key, leak) and confirm
  `verify.rs` flags every one `check_all` would have (extend `verify.rs`'s existing
  tamper tests). This closes the "does `check_all` catch anything `verify.rs` misses?"
  question.
- **Gate:** the study + a green tamper battery. No code change ships yet.
- **Abort condition:** if any real bug is caught by `check_all` but not `verify.rs`,
  stop and fold that rule into `verify.rs` first.

**STATUS: DONE.** The cross-check is implemented as `delta::tests::subsumes_*` — it re-runs
the same genuine-bug tampers as the `rejects_*` Δ guards but asserts **both** `check_all` and
`verify.rs` fire on one Core (helper `both_analyses`). The subsumption map, over `check_all`'s
seven negative-guard rules:

| `check_all` rule (tamper) | property | `verify.rs` mechanism | subsumed? |
|---|---|---|---|
| double-drop | double-free | `Cat::DoubleFree` (`do_drop` on a dead val) | ✅ |
| deep-drop-after-payload-move | double-free (child freed twice) | deep-drop-frees-children marks the moved child dead → later free = `DoubleFree` | ✅ |
| leak-at-return | leak | `Cat::Leak` (owned+live at exit), gate-worthy | ✅ |
| unbalanced-arms | leak on one path | per-path `Cat::Leak`, gate-worthy | ✅ |
| drop-key mismatch (container) | bad-free (wrong destructor) | `Cat::WrongDropKey` — **GAP FOUND + FOLDED IN** | ✅ (after fix) |
| drop-of-non-resource | well-formedness | — (not a memory-safety property) | out of scope¹ |
| use-of-unbound-variable | well-formedness | — (not a memory-safety property) | out of scope¹ |

¹ Structural well-formedness, not soundness: an unbound/alien variable never reaches Core in
real compilation (the front-end's scope + linearity checks reject it first). Only reachable by
deliberate tamper; excluded by construction.

**The one real gap Step 0 surfaced (and closed):** `verify.rs`'s drop-key cross-check
originally validated only the boxed-scalar tags (`Integer`/`String`); a **container** freed
with a bogus destructor key (`List$Int` dropped as `Wrong`) passed silently. Folded in
(`verify.rs`, `ctor_base`): a deep drop must name the value's own type *constructor*, compared
on the base before `$` so generic-vs-mono naming (`List` ↔ `List$Int`) is **not** a mismatch —
which keeps the check 0-false-positive (the very drift class that made `check_all` itself FP is
sidestepped) while catching a genuinely different constructor. Verified 0-FP over the whole
corpus (`verifier_reports_no_corruption_over_all_fixtures`).

### Step 1 — Make `verify.rs` the blocking Δ gate
**Files:** `scripts/` (+ `.github/workflows/ci.yml`).
- Add `scripts/verify-gate.sh`: build `--release` (or reuse the debug binary), run
  `axionc --emit verify` over `axionc/tests/fixtures/*.axi` + `examples/*.axi`, fail on
  any `FAIL:` line (corruption). This is the script form of the existing
  `verifier_reports_no_corruption_over_all_fixtures` test.
- In the `delta` job, **add** the verify gate as a **blocking** step (alongside the
  oracle + bench, which stay blocking).
- **Gate:** the new step is green on CI (it must be — `verify` is 0-FP and default-on
  already). CI stays green; the `delta` job now has a real soundness gate again.

**STATUS: DONE.** `scripts/verify-gate.sh` runs `--emit verify` over the whole corpus
(fixtures + examples), failing on any `FAIL:` corruption line or gate-worthy (non-`$step`)
`Leak:` line — the script form of `tests/verify.rs`. Local run: **237 verify clean, 36
skipped (rejections/malformed), exit 0** (237 + 36 = 273 = full corpus). Wired into the
`delta` job as a **blocking** step ("Δ soundness gate"), placed after the oracle and before
the (still-advisory, until Step 2) legacy Δ checker.

### Step 2 — Demote/retire the `check-delta` step
**Files:** `.github/workflows/ci.yml`, `scripts/check-delta.sh`.
- With Step 1's verify gate blocking, the advisory `check_all` step is redundant.
  **Remove it** (or, if Step 4 keeps coherence, narrow the script to coherence-only).
- **Gate:** CI green; `delta` job = oracle + verify-gate + bench (+ optional coherence).

**STATUS: DONE.** Removed the advisory `Δ checker gate` step from the `delta` job and
refreshed the job header comment to describe the two blocking gates (oracle + Δ soundness
gate). `scripts/check-delta.sh` is left in place for now — it still runs locally (`check_all`
is not retired until Step 3) and is deleted together with `check_all` there. `delta` job is
now: oracle → Δ soundness gate → bench.

### Step 3 — Retire `check_all` (the net-negative-code payoff)
**Files:** `axionc/src/delta.rs`, `axionc/src/lib.rs`.
- Delete `delta::check_all` and the `Ck` judgment machinery it drives (the ~500-line
  `Scope`/`Res`/`check_fn`/arm-typing rules) — **but not** `op_delta_effect`,
  `dump_annotated`, or `DeltaEffect`/`Res` types still used by the dump/verifier.
- `--check-delta` (lib.rs ~249-262): repoint to run only what survives (coherence, if
  kept — Step 4) or remove the flag. Keep `--emit core`/`--emit delta` intact.
- Migrate `delta::tests` that exercised `check_all` — either delete the now-dead ones or
  re-express the intent against `verify.rs` (which already has the double-free/UAF/leak
  unit tests). The `annotated_dump_locks_format` / determinism tests stay (they lock the
  dump, not the judgment).
- **Gate:** `cargo build` + full suite + **oracle byte-identical** (the dump is
  `op_delta_effect`-based, unaffected) + sanitize + differential + clippy/fmt. ~500
  lines deleted, zero behavior change.

### Step 4 — Decide `check_drop_coherence`'s fate
**Files:** `axionc/src/delta.rs`, `axionc/src/check.rs`, `scripts/check-delta.sh`.
The coherence check is the *only* guarantee `verify.rs` does not replicate: it catches
drift between the front-end liveness (`check.rs` DropPoints) and the Core. Two options:
- **(a) Retire it too** if `check.rs` DropPoints are confirmed fully vestigial (debug
  `print_drops` only, per delta-design §6). Then also consider trimming `check.rs`'s
  DropPoint computation. Smallest end-state; loses the drift guard.
- **(b) Keep coherence as a standalone, non-soundness regression guard** for `check.rs`
  (a separate `--check-coherence` / script step, clearly labeled "not the soundness
  gate"). Preserves the guard; keeps a small analysis alive.
- **Recommendation: (b), confirmed.** `check.rs` DropPoints are **not** vestigial —
  `analysis.drops` is consumed by the **LSP** (`lsp.rs:236`, the ownership inlay-hint /
  §8 draw-the-graph overlay) *and* the debug `--emit drops` (`lib.rs:226`). Since the
  LSP surfaces this front-end liveness to users, the coherence check (DropPoints ↔ the
  emitted Core) has real value as a guard that the LSP-shown ownership matches reality.
  Keep it as a standalone, clearly-labeled non-soundness check (`--check-coherence`),
  separate from the verify soundness gate.
- **Gate:** whichever chosen, CI green; the decision recorded in `delta-design.md`.

### Step 5 — Reconcile the docs + CI comment
**Files:** `docs/delta-design.md`, `docs/memory-model-options.md`, `.github/workflows/ci.yml`.
- Record that `verify.rs` (the drop-balance verifier) **is** the realized single Δ
  judgment — the design's endgame reached via the ASan-cross-checked implementation —
  and that `check_all` was retired as redundant. Update the `delta` job comment (drop
  the "advisory / superseded" note; it is now a real blocking verify gate).
- **Gate:** docs match reality; CI fully green with the Δ soundness gate blocking again.

## 4. Risk register

| Risk | Mitigation |
|---|---|
| `check_all` catches a real bug `verify.rs` misses | Step 0 subsumption study + tamper battery; abort/fold-in if found. `verify.rs` is already ASan-cross-checked (catches real bugs) and 0-FP — strong prior. |
| Deleting `check_all` breaks the dump/oracle | The dump (`dump_annotated`) and `op_delta_effect` are **separate** from `check_all`; oracle must stay byte-identical (a hard gate in Step 3). |
| Losing the check.rs↔Core drift guard | Step 4 keeps it as a standalone check if `check.rs` isn't vestigial. |
| CI regressions on 1.98 | Every step gated by the full pre-push checklist + a `gh` CI verification (locale-safe oracle, 1.98 clippy/fmt already green). |

## 5. Effort & payoff

- **Effort:** Step 0 (study + tamper battery) small; Step 1-2 (CI wiring) small; Step 3
  (retire `check_all`) medium but mechanical + net-negative code; Step 4-5 small.
  Overall: **medium**, front-loaded on the subsumption study (the trust-critical part).
- **Payoff:** the design's stated endgame — **one** proven linearity judgment, no
  drift-prone duplication, the Δ CI gate blocking and in-sync again, ~500 fewer lines,
  and `verify.rs`'s this-session hardening (drop-key + param types) becomes the
  canonical soundness authority.
