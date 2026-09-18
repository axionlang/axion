# Axión's memory-safety guarantee — the claim and its trust base

This document states, as precisely as the artifacts allow, **what Axión guarantees about the memory
safety of compiled programs, and exactly which parts of that guarantee are machine-checked, which are
validated on every compilation, which are tested, and which are trusted.**

The purpose is honesty of scope. A memory-safety claim is only as strong as its trusted base is small and
explicit. Nothing below overclaims: every "proven" row points at a machine-checked theorem, and every
trusted component is named with its current mitigation. Where the guarantee is conditional or incomplete,
it says so.

---

## 1. The top-level claim

> **Theorem (informal, conditional).** Let `P` be any program that `axionc` *accepts* and compiles to
> native code **without** the `--no-verify` or `--allow-leaks` escape hatches — the configuration a
> **`--certified` build enforces and stamps** (M5). Assume the trusted base of §4 is correct. Then, on
> **every** control-flow path, execution of the compiled binary:
> 1. never frees a heap resource twice (**no double-free**),
> 2. never uses a heap resource after it is freed (**no use-after-free**),
> 3. never frees a resource with the wrong reclaimer (**no bad-free / `WrongDropKey`**), and
> 4. leaves no heap resource unreclaimed at exit (**no leak**), *except* a characterized set of
>    conservative leaks (§5).
>
> For concurrent programs, additionally: the communication graph is acyclic by construction, and the
> system is **deadlock-free** with **session fidelity** and **cancellation-safety** — established at the
> graph/type level (§5 notes the value-level rung that remains deferred).

The guarantee is **conditional on the trusted base** and **scoped to the non-bypassed configuration** — a
scope that is now **machine-enforceable**: `axionc --certified` (M5) refuses `--no-verify`/`--allow-leaks`,
requires a native build, runs the full verifier (AX0910 + AX0911, and the AX0912 native-alias floor), and
stamps the artifact on success, so a certified build provably occupies exactly the theorem's hypothesis.
The rest of this document is the decomposition of that conditional into checked and trusted parts.

---

## 2. The pipeline and where the guarantee is established

```
source .axi
  │  parse / infer / linearity-check        → front-end (soundness of acceptance: TESTED)
  │  Auto-Drop reclamation → Core            → inserts the free()s
  ▼
final drop-inserted Core  (core::Lowered)
  │  verify.rs                               → TV-PER-COMPILE (AX0910 corruption, AX0911 leak)
  │  heap_alias_violations                   → AX0912 conservative native floor
  ▼
codegen.rs (Cranelift) / llvm.rs (→ LLVM IR)  → TRUSTED (differential-tested only)
  │  + axion-rt (Rust staticlib, 0 LOC C)     → TRUSTED (ASan/LSan + fuzz only)
  ▼
native binary
```

The **checked oracle** is `verify.rs` (`axionc/src/verify.rs`): per function, per path, over the final
drop-inserted Core, it proves every heap resource is freed exactly once and never after free, delegating
move/borrow/produce classification to the single authority `delta::op_delta_effect`. It is **translation
validation run on every native compilation** (`lib.rs:449-564`), default-on; a corruption finding refuses
to emit (AX0910). The interpreter is not gated — it reclaims via Rust `Drop` and does no manual
reclamation.

The **machine-checked metatheory** (`metatheory/*.lean`) proves that the *judgment `verify.rs` implements*
is sound: accepted ⟹ no double-free / UAF / bad-free / leak, on every path.

---

## 3. Classification table

| Pipeline step / property | PROVEN (Lean) | TV-per-compile | TESTED | TRUSTED |
|---|---|---|---|---|
| Drop-balance judgment is sound (no double-free/UAF, all paths) | `AxionDrop.sound`, `no_corruption`, `no_leak` | — | — | — |
| Interior aliases / borrows (drop-of-alias, dangling use, V-1↔R-5) | `AxionAlias.*` (`drop_of_alias_rejected`, `dangling_use_rejected`, `v1_*`) | — | — | — |
| Reclaimer keys (bad-free / `WrongDropKey`) | `AxionKey.*` (`no_bad_free`, `wrong_key_drop_rejected`) | — | — | — |
| Move / escape (escape ≠ leak) | `AxionMove.*` (`escape_is_leak_free_accepted`, `*_after_move_rejected`) | — | — | — |
| Concurrency: deadlock-freedom | `AxionSession.*` (`progress` T2, `no_deadlock` T4) | — | — | — |
| Concurrency: fidelity + cancellation | `AxionFidelity.*` (`fidelity` T3, `cancellation_receivable` T5a, `no_self_ancestor` T5c) | — | — | — |
| Real program's Core actually satisfies the judgment | — | **`verify.rs`** (AX0910/AX0911) | — | — |
| Front-end acceptance (parse/infer/linearity) is sound | — | — | fixtures, fuzz | the front-end passes |
| Backend lowering preserves **reclamation** (LLVM path, incl. destructor bodies) | — | **`codegen_tv.rs`**: emitted IR's frees match the Core reclamation 1:1 — user-fn `Drop`s AND generated `axion_drop_*` destructor child-drops/shell frees — checked per-compile; corpus gate validates **2529 calls, 0 discrepancies** (`tests/codegen_tv.rs`) | teeth unit-tests catch dropped/duplicated/mis-keyed/destructor-shell frees | value-level *semantic* correctness of lowering, and destructor-generation-vs-type-layout (ASan/LSan-gated), still trusted |
| Backend lowering preserves *semantics* (compute) | — | — | `runtime_backends_agree` (`run.rs:4458`), `props_mem.rs`, ASan/LSan, ~9000 fuzz | **all of `codegen.rs`, `llvm.rs`, `interp.rs`** |
| Runtime reclamation primitives | key-matching *discipline* modeled in `AxionKey` | — | ASan/LSan (`sanitize.sh`), fuzz | **`axion-rt` (Rust; 0 LOC C)** |
| Model faithfully abstracts `verify.rs` | — | — | **8 curated shapes** (`bridge.rs`) + **whole in-fragment corpus**: executable `AxionDrop.acceptsL` (proven == `accepts`) machine-checked to equal the verifier's verdict on **464 functions** (`--emit model-trace`, `metatheory/model-trace.sh`) | functions outside the `alloc/use/drop/moveOut/borrowed-param/branch/scalar-case` fragment (heap-extracting `case`/keys, escaping borrows, closures, arrays, sessions) |
| `verify.rs` implementation itself is correct | — | — | its verdicts on fixtures/fuzz; bridge on 8 shapes | **the verifier's own Rust** |

Lean side: built with stock Lean 4 (no Mathlib) via `nix shell nixpkgs#lean4`; `check.sh` asserts **no
`sorry`** and that `sound` depends only on **`propext`** and **`Quot.sound`**.

---

## 4. The trusted base (named, with mitigation)

Each item below is load-bearing and **not** machine-checked. Irreproachability is measured by how small
and well-mitigated this list is.

1. **The three backends** — `codegen.rs` (Cranelift), `llvm.rs` (LLVM IR), `interp.rs`. *Reclamation
   preservation on the LLVM path is now translation-validated per-compile* (**M3**, `codegen_tv.rs`):
   the emitted IR's frees must match the Core `Drop` sites 1:1, so a lowering that drops/duplicates/
   mis-keys a free is caught (the miscompile class). Remaining trusted: the *value-level semantic*
   correctness of all three backends' compute lowering (rests on differential agreement + ASan/LSan +
   fuzz), and Cranelift's reclamation (not yet TV'd — same technique applies).
2. **The runtime `axion-rt`** — now **100% Rust, 0 lines of C** (was ~1900 LOC of hand-written C).
   The **entire** runtime is the Rust crate `axion-rt`: bignum (reuses `src/bigint.rs`), strings/IO,
   the OS-capability layer (fs/subprocess/rand/tty/args), the heap allocator, arenas, the flat
   collections (arrays/buffers/tritvec/i8/i32), networking, **and the M:N session/parMap scheduler**
   (`std::thread` + `Mutex<Inner>`) — the C→Rust port is complete (docs/rust-runtime-port.md, Stages
   1–4b; `axion_rt.c` deleted). It builds with `std::io`/`std::fs`/`std::process`/`std::thread`; `libc`
   only for `termios`, the `malloc`/`free`-backed header allocator, and the TCP wrappers. `unsafe` is
   confined to small, documented pointer/layout/FFI blocks. This shrinks the C in the TCB to **zero**
   and lifts a decisive property for free: because the scheduler's shared state lives behind
   `Mutex<Inner>`, **data-race-freedom is now a compile-time guarantee** (Rust `Send`/`Sync` + the
   borrow checker), not a per-run ThreadSanitizer sample. Still trusted (checked by ASan/LSan + fuzz +
   the concurrency stress gate `scripts/tsan.sh`): the `unsafe` blocks and the value-level behavior.
3. **`verify.rs` as Rust** — the checked oracle is itself unverified code standing in for the Lean proofs.
   The 8-shape bridge is the only tie between them. Mitigation target: **M2** (whole-fragment bridge),
   then north-star extraction of the verifier from the model.
4. **The front-end** — parser, inference, linearity checker: soundness of *acceptance* is tested, not
   proven.

---

## 5. Escape hatches and characterized incompleteness

- **`--no-verify`**: bypasses the verifier entirely (both AX0910 and AX0911). **A program the verifier
  flagged as a double-free can be emitted.** The top-level claim explicitly excludes this configuration.
  **Mitigated (M5, DONE):** `axionc --certified` refuses this flag (exit 2), so the guarantee-bearing
  configuration is machine-enforceable rather than merely documented.
- **`--allow-leaks`**: permits AX0911 leaks but **keeps** AX0910 corruption checking. Leaks are safe (no
  corruption), so this weakens only clause (4) of the claim. **`--certified` refuses it too** (M5).
- **AX0912 native floor** (`lib.rs:468-503`, `heap_alias_violations`): an element-aliasing borrower
  (`filter`/`take`/`head`/`last`) instantiated at a **heap** element type, and a nested-tuple poly-payload
  the monomorphizer cannot lower, are **rejected for native emit**. This is **sound-by-construction** — a
  clean rejection instead of a silent UAF, not a hole in the guarantee. The interpreter still runs them.
  It is an *expressiveness* limit, not a safety one.
- **Conservative leaks** (`verify::leak_gates` whitelist): session/parmap `*$step` and some polymorphic
  elements are known-conservative leaks Auto-Drop does not reclaim. These are the "except" in clause (4);
  they are safe (no corruption) and characterized, not unbounded.
- **Concurrency T1/T3/T5 value-level** (separation logic / Iris-Actris): the deadlock/fidelity/cancellation
  results are proven at the **graph/type** level (`AxionSession`, `AxionFidelity`); the value-level
  subject-reduction and memory-orphan claims are **deferred** (stated in `docs/phase-3-calculus.md` §6,
  noted in `README.md`). The concurrency clause of the top-level claim is scoped accordingly.

---

## 6. What would raise the guarantee (roadmap pointers)

The trusted base of §4 and the deferrals of §5 are the frontier. In descending credibility-per-effort:

- **M2 — whole-fragment bridge** (`--emit model-trace`): **DONE.** The executable `AxionDrop.acceptsL`
  (proven == `accepts` by `AxionDrop.chk_correct`, hence memory-safe + leak-free by `AxionDrop.sound`) is
  machine-checked (Lean `by rfl`) to equal `verify.rs`'s verdict on every function in the
  `alloc/use/drop/moveOut/branch` fragment — **426 of 1220 corpus functions, zero disagreements**
  (`metatheory/model-trace.sh`, wired into `bridge.sh`; translator `axionc/src/model_trace.rs`). This
  replaces "proved a toy + spot-checked 8 cases" with corpus-wide agreement over the modeled fragment.
  Remaining widening: executable checkers for the interior-alias (`AxionAlias`) and reclaimer-key
  (`AxionKey`) slices, to pull more functions in-fragment.
- **M3 — reclamation-preservation TV for codegen: DONE (LLVM path).** `axionc/src/codegen_tv.rs` +
  `--emit codegen-tv` independently derive the reclamation the Core `Drop` sites require and the
  reclamation the emitted LLVM IR performs, and check they match 1:1 per function. Corpus gate
  (`tests/codegen_tv.rs`): 1397 reclamation calls validated across the corpus, zero discrepancies; teeth
  unit-tests confirm it catches a dropped/duplicated/mis-keyed free. Attacks trusted item (1) — the layer
  where the real historical bugs lived. **M3.5** extended it to the generated `axion_drop_*` destructor
  bodies (their `Op`-level child-drops + shell frees), raising the validated surface to 2529 calls.
  Remaining: extend the same TV to the Cranelift backend, and (a larger step) value-level semantic TV of
  compute lowering. (Destructor generation-vs-type-layout is a direct `RecordInfo` loop, ASan/LSan-gated.)
- **M4 — bounded-exhaustive checking**: enumerate every well-typed in-model program up to size *k* through
  the M2 bridge + sanitizers, turning "~9000 random" into "none missed up to *k*".
- **M5 — certified build mode (DONE)**: `axionc --certified` refuses `--no-verify`/`--allow-leaks`,
  requires a native build, runs the full verifier, and stamps verification status on success — closing
  the §5 bypass hole for the guarantee-bearing configuration (`certified_build_mode_enforces_verification`
  in `tests/run.rs` locks in all four behaviors).
- **North star**: extract `verify.rs` from the Lean model (removes trusted item 3 entirely); mechanize
  T1/T3/T5 in Iris/Actris; shrink the `unsafe` in `axion-rt` toward zero / verify it (trusted item 2).

---

## 7. Reproducing the checks

```sh
./metatheory/check.sh    # Lean: every theorem type-checks, no sorry, propext/Quot.sound only
./metatheory/bridge.sh   # Lean proofs + verifier agreement on the 8 canonical shapes
./scripts/sanitize.sh    # ASan/LSan ground truth over the native fixtures
./scripts/fuzz.py        # differential interp-vs-native fuzzing
cargo test               # includes the fuzz gate, props_mem, bridge, and backend-agreement tests
```
