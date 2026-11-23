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
> 4. leaves no heap resource unreclaimed at exit (**no leak**). The verifier proves this for every
>    function except the leak accounting of polymorphic extracted fields (§5), which LeakSanitizer
>    gates instead: every native fixture is leak-checked, with no exempt subset.
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
| Backend lowering preserves **reclamation** (**BOTH** native backends, incl. destructor bodies) | — | **`codegen_tv.rs`**: emitted frees match the Core reclamation 1:1 — user-fn `Drop`s AND generated `axion_drop_*` destructor child-drops/shell frees. **LLVM** IR (`--emit codegen-tv`, `tests/codegen_tv.rs`) AND **Cranelift** CLIF (`--emit codegen-tv-clif`, `tests/codegen_tv_clif.rs`): each validates **2525 calls over 251 fixtures, 0 discrepancies**, and the two agree per-fixture | teeth unit-tests (LLVM + CLIF) catch dropped/duplicated/mis-keyed/destructor-shell frees | value-level *semantic* correctness of lowering, and destructor-generation-vs-type-layout (ASan/LSan-gated), still trusted |
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
   preservation on **both native backends** is now translation-validated* (**M3**, `codegen_tv.rs`):
   the emitted frees — LLVM IR *and* Cranelift CLIF — must match the Core `Drop` sites 1:1, so a
   lowering that drops/duplicates/mis-keys a free is caught (the miscompile class). Remaining trusted:
   the *value-level semantic* correctness of all three backends' compute lowering (rests on
   differential agreement + ASan/LSan + fuzz).
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
5. **Integer refinements' fact extraction** (`refine.rs`, docs/refinements.md) — an array access the
   refinement checker proves in bounds is compiled without its check. The *arithmetic* of each proof
   is not trusted: it carries a certificate that `check_cert` replays, `AxionRefine.lean` proves
   that checker sound (`sound`: an accepted certificate means no integer solution), and
   `refine-trace.sh` re-checks every corpus certificate with the Lean `check`. Trusted: reading the
   facts and goal off the program (comparisons, overflow, lengths) — mitigated by the `refine`
   fuzzer (interp vs native, ASan).
6. **Totality** (`total.rs`, docs/totality.md) — opt-in, and not part of the memory-safety
   guarantee. Each accepted recursive group's size-change closure is a certificate that
   `sct-trace.sh` re-checks with Lean (`AxionSct.lean` proves what an accepted one means; the
   size-change theorem itself is cited, not proven). Trusted: the pattern-coverage check and
   reading the size-change graphs off the program.
7. **SIMD vector lowering** (`simd.rs`, docs/simd.md) — vectors are plain values (nothing to
   reclaim), so the ownership guarantee is untouched; what is trusted is their representation.
   `simd::analyze` decides which values live in vector registers and rejects a vector anywhere only
   a 64-bit slot fits (AX0915); the backends' vector code is part of item 1. A vector load/store's
   element accesses are unchecked after one range check (`mark_range_lanes`: the accesses carry the
   check's span and index from its result). Mitigated by the `simd` fuzzer (interp vs Cranelift vs
   LLVM + ASan, random out-of-range indices) and the fixtures `simd*.axi`.

---

## 5. Escape hatches and characterized incompleteness

- **`--no-verify`**: bypasses the verifier entirely (both AX0910 and AX0911). **A program the verifier
  flagged as a double-free can be emitted.** The top-level claim explicitly excludes this configuration.
  **Mitigated (M5, DONE):** `axionc --certified` refuses this flag (exit 2), so the guarantee-bearing
  configuration is machine-enforceable rather than merely documented.
- **`--allow-leaks`**: permits AX0911 leaks but **keeps** AX0910 corruption checking. Leaks are safe (no
  corruption), so this weakens only clause (4) of the claim. **`--certified` refuses it too** (M5).
- **AX0912 native floor** (`lib.rs`, `heap_alias_violations`): an element-aliasing borrower
  (`filter`/`take`/`head`/`last`) instantiated at a **heap** element type, and any element-extracting
  list consumer over a **tuple** element type (the nested-tuple poly-payload the monomorphizer cannot
  lower), are **rejected for native emit**. This is **sound-by-construction** — a clean rejection
  instead of a silent UAF/miscompile, not a hole in the guarantee. The interpreter still runs them.
  It is an *expressiveness* limit, not a safety one.
  - *Precise boundary (validated 2026-10-10, `--no-verify` + ASan over a function×shape matrix; see
    the `heap_alias_violations` comment).* The floor is load-bearing, not merely conservative:
    forcing it off, `filter` over a tuple element genuinely **double-frees** (ASan-confirmed) and
    `take`/`drop` hit a genuine monomorphizer hole (they **drop the caller**). But it also
    **over-rejects**: full-consume rebuilders — `reverse`/`map`/`length` over a tuple element —
    lower correctly and are ASan-clean, yet are refused (their elements escape via the result, so the
    coarse `escaping` classifier flags them). A safe narrowing needs a view-vs-rebuild predicate that
    also holds for user functions (the clean signature split fails — `reverse`/`take`/`drop` are all
    `List a -> List a`, all `%1`), so a naive relaxation would ship a miscompile; the floor is kept
    intact. The sound workaround is a **named `data` record element** instead of a bare `(K, V)`
    tuple (e.g. `examples/json.axi`'s `data Member = Member String Json`); the real fix is to close
    the monomorphizer residual (deep monomorphizer work, not a guard tweak). So: some *currently
    rejected programs are in fact safe* (the rebuilders) — an honest expressiveness cost beyond the
    strict minimum, bounded and worked-around, never a safety compromise.
- **Leaks — no characterized exceptions (2026-11-15).** Clause (4) used to carry a list of known
  conservative leaks. Each is closed and leak-gated:
  - *`Integer` fields of `data`/record types* are reclaimed by the container's destructor like `String`
    fields (`con_drop_slots`); an extracted field is moved out and the container frees only the rest
    (skip destructors, a shell-free after a `case`). The 2026-10 attempt at this was rejected because
    it refused `map getV`; the ownership inference added since (consumed parameters, per-clone
    re-inference) makes the same change sound and leak-free. Regression: `integer_field_reclaim.axi`.
  - *Views* (`tail`, `dropWhile`, `delete`, any function returning its list's own tail) consume their
    list: consume-inference marks a generic view's list `%1` (Rule V), so the skipped cells and
    elements are freed instead of "leaking the dropped prefix". Regression: `view_consumes_reclaim.axi`.
  - *Session/parMap state machines* (`*$step`): a parMap worker tracks ownership like a `spawn`ed task
    (it used to be generated untracked), and a fresh runtime result is classified by the built-in
    ownership table. `verify::leak_gates` no longer whitelists `*$step`: a leak there is AX0911.
  - *A field read out of an owned record that dies* is a move-out (`drop v : T skip{slot}`), so the
    record's shell no longer leaks (`accum_field_alias.axi`, `poly_payload_borrow_return.axi`).
  - *Closures* are reclaimed: a closure call BORROWS the closure (it may be called again) and the cell
    is freed after its last call; the cell holds pointers to its captures, so the frame frees a
    capture only after the closure's last use (Auto-Drop's `borrow_aliases`, the verifier's
    `Val.borrows`). This also closed a silent use-after-free: Auto-Drop used to free a heap capture
    right after building the closure, before calling it (or returning it), and neither the verifier
    nor ASan saw the read (it happens inside the runtime). Regression: `closure_reclaim.axi` and the
    verifier test `closure_capture_must_outlive_its_calls`.
    A closure that ESCAPES its frame owns COPIES of its heap captures: they move into the cell,
    laid out `{fn_ptr, dtor, copier, captures…}`, whose generated destructor/copier
    (`axion_drop_clo$<lambda>` / `axion_copy_clo$<lambda>`) free/copy them. A function value has the
    destructor key `Closure` (`axion_closure_drop`, `axion_closure_copy`), also as a field:
    a `Maybe`/list/tuple of closures frees and copies each one. Ownership is explicit at every
    hand-off: a closure RETURNED (by a function returning a fresh closure on every path, or one
    whose clause arity is below its signature's) is owned by the caller; a closure put into a
    structure is MOVED in only if it is a fresh closure used nowhere else, otherwise a COPY goes
    in (a borrowed parameter, an element of a borrowed structure, a closure embedded twice — these
    were double frees while the change was made); a `%1` function-typed parameter is freed by its
    function; a function-typed parameter returned whole is returned as a copy. Regressions:
    `closure_escape_owned.axi`, `closure_in_structures.axi`, `closure_fields.axi` (callback records:
    `data` types with function fields), `closure_fuzz_regressions.axi` (all leak-gated).
    The drop verifier CHECKS these hand-offs (it no longer relies on Auto-Drop getting them
    right): a closure value carries the key `Closure` (also a function-typed parameter); putting
    a closure the function does not own into a constructor/tuple/record is `DropOfAlias`; a
    moved-in closure stored twice is `Duplicated`; a call returning a by-copy update of its
    argument shares that argument's unset heap fields (element-share summary), so freeing both
    is `DoubleFree` (checked in both free orders). `tests/verify.rs`
    `verifier_refuses_shared_closures_without_the_copies` turns Auto-Drop's closure copies off
    (`AXION_NO_CLOSURE_COPIES`) and requires the refusals; per program, every native double free
    that results is refused. A moved-in closure (or String/Integer/Buffer) a function neither
    returns nor frees is a reported leak (AX0911) — no longer exempt (see below).
  The verifier's leak accounting now covers MOVED-IN parameters: the exemption is gone. It
  existed because the borrow analysis (`op_moves`/`op_nonborrow`) read three pure reads as moves —
  a closure capture, an FFI `Borrow` argument, a runtime call the built-in table says borrows —
  so callers handed over values their callees only read and nobody freed them (latent leaks in
  `closure_reclaim`, `ffi_effects`, `ffi_own`, `stderr_exit`, and `axfm`'s `bulkRun`, masked by
  static-literal arguments). It now reads them as `delta::op_delta_effect` does, and a moved-in
  value a function neither frees nor returns is AX0911 (`verifier_reports_a_moved_in_parameter_
  never_freed`). ONE narrow exemption remains: a field of a polymorphic constructor whose type
  stays a bare type variable in a GENERIC body (`delBy$$p`'s dropped `y` before class
  specialization) — no reclaimer exists for an unknown type there; the specialized clones that
  actually run at heap types are fully accounted. A field the scrutinee's key resolves to a heap
  type is no longer exempt. LSan still leak-gates every native fixture (`scripts/sanitize.sh`).
- **Owned `String` parameters in a tail-recursive accumulator — NOW RECLAIMED, SOUNDLY** (`core.rs`
  seeding of `reclaim_cond_escape`, default-**on**): an owned `String` *parameter* rebuilt each step of a
  tail recursion — `go acc n = … go (strAppend acc …) …`, the shape behind a `cmdLine`/search key
  accumulator — is now reclaimed each step (previously a characterized leak). Closed by the interprocedural
  **borrowed-element precision** (`verify::borrowed_elem_params`, "`bep`"): an owned `String` param is
  reclaimed iff no call site anywhere passes it a borrowed container element. This keeps the genuinely-owned
  accumulator reclaiming while still **not** reclaiming a `String` param that receives a borrowed element
  (`work` borrows a `List String`, passes each element to a `consume`; the `axpass show` fzf path) — the
  double-free a blanket reclaim would create, and which the verifier correctly **AX0910-rejects**.
  `axionc/tests/fixtures/borrowed_list_elem_consume.axi` remains the regression guard (must verify + ASan
  clean, **not** be rejected); the escape hatch `AXION_STRING_RECLAIM=1` bypasses the `bep` exclusion to
  force the unsound blanket reclaim and prove the verifier is the backstop
  (`verifier_catches_borrowed_list_element_double_free`). This is the owned-vs-borrowed-element precision
  (roadmap §6, [[axion-partial-consumer-uaf]]) applied to `String` *params*; the analogous **destructor
  field-drop** case (the `Integer`/`String` *field* extract-and-escape above) still needs the per-field
  move-out and remains a characterized leak.
- **Heap-consuming `where`-local functions — NOW RECLAIMED; a leak-check FALSE-NEGATIVE now CLOSED**
  (`core.rs` `lower_func` + the `where`-local `param_mults` registration): a lambda-lifted `where`-local
  has no written type signature, and both Auto-Drop's owned-param computation and the `%1` linearity check
  were gated on `f.sig`. So a `where`-local that *consumed* a heap parameter (destructured a `List
  String`/`data`, rebuilt a result) got **no** owned params → **no drops inserted → it leaked every heap
  value it consumed**, while the drop-balance verifier — tracking only owned params — saw an empty `Δ`,
  reported "balanced", and **certified the leak as leak-free** (a genuine false-negative in clause (4), not
  a characterized conservative leak; LSan proved the leak the verifier missed, e.g. a balanced-`unlines`
  helper). Closed by treating a `where`-local like a signed top-level `%1` function: its inferred param
  types are exported from inference (`infer.rs` `where_param_tys`, mirroring `where_ret_tys`) and
  `lower_func` owns each genuinely-heap one (`push_owned`, same `heap_ty`/`mono_key` path as the signed
  branch), with the call-site borrow analysis registering those owned params as `Once` so a self-recursive
  call **moves** (not borrow+drops) its own arg — the coordination without which the callee's drop and the
  caller's post-call drop would double-free. Owning is sound by the same argument as top-level: destructuring
  an owned container **moves** the element out, so even returning a case-extracted element
  (`case ys of Cons a _ -> a` → `drop r; drop ys; ret a`) is leak-free, not a borrow; the drop-verifier
  (AX0910) and the AX0912 floor remain the backstops for any genuinely unsound shape. The verifier now
  tracks a non-empty `Δ` for these locals, so a *missing* drop is caught (AX0911) — the false-negative is
  gone. Regression: `axionc/tests/fixtures/where_local_unlines.axi` (LSan-gated, must be leak-free, not
  merely verify-clean); `where_alias_returns_element.axi`, which previously leaked conservatively, now
  reclaims. (The earlier result-type `heap_ty` heuristic that misclassified a `String`-returning consumer
  like `ulBal` as a borrower was the specific bug; the fix replaces it with per-param ownership.)
- **Concurrency T1/T3/T5 value-level** (separation logic / Iris-Actris): the deadlock/fidelity/cancellation
  results are proven at the **graph/type** level (`AxionSession`, `AxionFidelity`); the value-level
  subject-reduction and memory-orphan claims are **deferred** (stated in `docs/phase-3-calculus.md` §6,
  noted in `README.md`). The concurrency clause of the top-level claim is scoped accordingly.
- **The FFI boundary** (`Op::Ffi`, `foreign` imports): the verifier, linearity checker, and Lean model
  **all stop at a foreign call** — a function containing one is out-of-fragment for the model-trace bridge
  (`model_trace.rs` → `Err("ffi")`). The guarantee holds for the Axión code *up to* the call (buffers
  reclaimed + bounds-checked, ownership accounting sound and verifier-enforced via `Own`/`Borrow`, handles
  type-distinct, interpreter refuses non-faithful signatures), but the C callee and any raw pointer that
  escapes to it (`bufPtr`/`bufPtrN`/`intToPtr`/`ptrToInt`, a returned handle, an `Own` ownership assertion)
  are **trusted, not proven** — misuse is UB the compiler cannot catch. This is an honest limit of scope,
  not a hole in the in-scope claim; the theorem never quantified over C behavior. Full treatment, the
  safe-FFI contract, and the two deferred hardenings (linear handles; a scoped `withBufPtr` bracket) are in
  **`docs/ffi-trust-boundary.md`**.

---

## 6. What would raise the guarantee (roadmap pointers)

The trusted base of §4 and the deferrals of §5 are the frontier. In descending credibility-per-effort:

- **M2 — whole-fragment bridge** (`--emit model-trace`): **DONE.** The executable `AxionDrop.acceptsL`
  (proven == `accepts` by `AxionDrop.chk_correct`, hence memory-safe + leak-free by `AxionDrop.sound`) is
  machine-checked (Lean `by rfl`) to equal `verify.rs`'s verdict on every function in the
  `alloc/use/drop/moveOut/branch` fragment — **2655 of 3059 corpus functions (86.8%), zero disagreements**
  (`metatheory/model-trace.sh`, wired into `bridge.sh`; translator `axionc/src/model_trace.rs`). This
  replaces "proved a toy + spot-checked 8 cases" with corpus-wide agreement over the modeled fragment.
  Remaining widening: executable checkers for the interior-alias (`AxionAlias`) and reclaimer-key
  (`AxionKey`) slices, to pull more functions in-fragment.
- **M3 — reclamation-preservation TV for codegen: DONE (BOTH native backends).** `axionc/src/codegen_tv.rs`
  independently derives the reclamation the Core `Drop` sites require and the reclamation the emitted code
  performs, and checks they match 1:1 per function. **LLVM** via `--emit codegen-tv` (`tests/codegen_tv.rs`)
  and **Cranelift** via `--emit codegen-tv-clif` (`tests/codegen_tv_clif.rs`, resolving CLIF's `u0:N`
  FuncId indices through the `codegen::emit_ir_tv` symbol maps): each validates **2525 calls over 251
  fixtures with zero discrepancies, and the two agree per-fixture**; teeth unit-tests (LLVM + CLIF) confirm
  a dropped/duplicated/mis-keyed/destructor-shell free is caught. **M3.5** covers the generated
  `axion_drop_*` destructor bodies (`Op`-level child-drops + shell frees). Attacks trusted item (1) — the
  layer where the real historical bugs lived. Remaining (larger step): value-level semantic TV of compute
  lowering. (Destructor generation-vs-type-layout is a direct `RecordInfo` loop, ASan/LSan-gated.)
- **M4 — bounded-exhaustive checking (DONE)**: a generator enumerates EVERY program in a bounded
  drop/move/branch fragment up to size *k* (k≤3 ⇒ 98 programs), and checks two oracles exhaustively —
  turning "~9000 random cases" into "none missed up to *k*". **Runtime half** (`tests/exhaustive.rs`,
  clang-only, CI-friendly): every program the verifier ACCEPTS (28) runs AddressSanitizer +
  LeakSanitizer-clean, and the 70 rejects are genuine AX0910/AX0911 — so *accept ⇒ safe* holds on the
  whole family. **Model half** (`metatheory/exhaustive.sh`, wired into `bridge.sh`): the same 98
  programs yield 311 `acceptsL … = ⟨verifier-verdict⟩ := by rfl` examples that Lean type-checks — so the
  proven-sound model AGREES with the verifier on every in-fragment program. Together: **model == verifier
  == runtime, exhaustively over the family** (the arm-fate combinations sweep the branch-merge decision
  boundary where the historical drop-balance bugs lived).
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
./metatheory/refine-trace.sh  # Lean re-checks every refinement certificate the compiler produces
./metatheory/sct-trace.sh     # Lean re-checks every totality size-change certificate
./metatheory/bridge.sh   # Lean proofs + verifier agreement on the 8 canonical shapes
./scripts/sanitize.sh    # ASan/LSan ground truth over the native fixtures
./scripts/fuzz.py        # differential interp-vs-native fuzzing
cargo test               # includes the fuzz gate, props_mem, bridge, and backend-agreement tests
```
