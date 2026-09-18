# Porting the `--release` runtime from C to Rust

**Status: COMPLETE (Stages 1–4b).** The hand-written C runtime (`axionc/src/axion_rt.c`, ~1900 LOC, 124
raw `malloc`/`free`/`memcpy` sites) has been fully replaced by the Rust crate `axion-rt` and **deleted** —
the `--release` path now links a Rust staticlib and the TCB contains **zero lines of C**. This shrank the
trusted computing base at the layer where the only real memory bug ever shipped (the `bn_divmod`
double-free/leak) and made the session scheduler's data-race-freedom a **compile-time** property
(`Mutex<Inner>` + `Send`/`Sync`) rather than a ThreadSanitizer sample. The stage table below records the
plan as executed.

## Why

The memory-safety guarantee is machine-checked down to Core reclamation, and per-compile reclamation is
now translation-validated into the emitted LLVM IR (`codegen_tv.rs`). But the frees themselves are executed
by `axion_rt.c` — hand-written C, the **largest trusted component** and the one place a real bug lived. The
interpreter (Rust `Drop`) and the Cranelift backend (its own inline runtime) are already Rust; only the
LLVM/`--release` path links C. This is a pragmatic bootstrapping artifact, not a principled choice.

A Rust runtime does not make the inherently-unsafe work (raw i64↔pointer per the ABI, in-place linear
reclamation, deep-drop by offset) *safe* — those stay `unsafe`. What it buys: the unsafety is **contained
and auditable** instead of pervasive; internal temporaries use RAII (`Vec`/`Box`), which makes the
`bn_divmod` bug class impossible; the runtime gets Miri / `cargo-fuzz` / UB checks; and the three runtimes
can **unify** (killing the `runtime_backends_agree` drift guard).

## Surface inventory (~110 exported `axion_*` functions)

| Group | ~fns | Nature | Port target | Stage |
|---|---:|---|---|---|
| **Bignum** (`bn_*`, `axion_bignum_*`) | 20 | *Already a mirror of `src/bigint.rs`* | **Reuse `bigint.rs`** — the tested Rust twin; deletes the bug site | **1** |
| Strings / IO (`puts`/`put`/`show_int`/`show_float`/`strcat`/`str_len`/`str_at`/`str_cmp`/`substr`/`str_drop`) | ~14 | logic safe; block alloc unsafe | safe Rust + small `unsafe` for the heap-block header | 2 |
| OS capability (`getenv`/`read_file`/`write_file`/`mkdir_p`/`unlink`/`rename`/`readdir`/`rand_hex`/`read_line`/`read_secret`/`exec_*`/`system`/`run`/`exit`/`set_args`/`getarg`) | ~20 | thin libc wrappers (fork/exec/pipe/termios/dirent) | `std::fs` / `std::process::Command` / `std::io` / `/dev/urandom` — **much smaller + safer** than the C | 2 |
| Heap allocator (`axion_alloc`/`free`/`block_copy`/`xmalloc`/`xrealloc`) | 5 | raw, header-at-offset-−8 | contained `unsafe` mirroring the exact layout | 3 |
| Arenas (`arena_new`/`alloc`/`reset`/`mark`/`release`/`promote`) | 6 | bump allocator, stable ptrs | contained `unsafe` | 3 |
| Flat collections: Buffer / Array / TritVec / I8 / I32 (`new`/`get`/`set`/`len`/`sum`/`dot`/`iota`/`matvec`) + `list_to_buf`/`buf_to_list`/`fold_bytes` | ~40 | raw pointer indexing, **hot** | contained `unsafe`; keep the vectorizable reductions | 3 |
| M:N session scheduler (`sess_new`/`channel`/`send`/`recv`/`pending`/`alloc`/`spawn`/`run`, `par_map`, `run_main`/`main_trampoline`) | ~11 | `pthread` + mutex/condvar + raw step fn-ptrs | `std::thread` + `Mutex`/`Condvar`/channels; step call is one `unsafe` transmute | **4** |
| Networking (sockets) | ~8 | libc sockets | `std::net` | 4 |

External C deps replaced by std: `pthread`/`sched` → `std::thread`/`std::sync`; `dirent`/`sys/stat` →
`std::fs`; `sys/wait`/`fork`/`exec` → `std::process`; `termios` → a tiny `unsafe` (no-echo read) or the
`rustix`/`libc` crate; `arpa/inet`/`socket` → `std::net`.

## The enabling change (Stage 0): build + link

Today `llvm.rs` `include_str!`s `axion_rt.c`, writes it next to the emitted `.ll`, and calls
`clang -O2 -flto -pthread prog.ll rt.c -o exe`.

Plan:
1. New workspace crate **`axion-rt`** with `crate-type = ["staticlib"]`, `panic = "abort"` (a Rust panic
   unwinding across the C/IR FFI boundary is UB — abort at the boundary), every entry `#[no_mangle]
   pub extern "C" fn axion_*(… : i64) -> i64` (the **unchanged** uniform i64 ABI, so *no emitted-IR
   change*).
2. `axionc`'s `build.rs` builds `axion-rt` to a `.a` and `include_bytes!`s it (mirrors today's
   `include_str!` — keeps `axionc` a self-contained binary).
3. `llvm.rs` writes the `.a` and links `clang -O2 prog.ll axion-rt.a -pthread -o exe` (plus the user's
   `foreign_libs` as now).

**Tradeoff — LTO:** cross-language `-flto` inlining of hot runtime calls (e.g. `array_get` into a loop) is
lost across the clang-IR / rustc-staticlib boundary. Mitigation: `-O2` both sides; keep hot flat-collection
ops trivial; gate with `scripts/bench.sh --check` (the perf baseline). Correctness > the inlining nicety;
matched-LLVM cross-lang LTO can be revisited later.

## Staging (each stage ships independently, differential-green)

- **Stage 1 — Bignum (highest value, likely smallest).** Route the runtime's Integer ops to `bigint.rs`
  via `extern "C"` shims. Deletes ~250 lines of the most bug-prone C (`bn_divmod` et al.) and unifies with
  the interpreter's already-tested bignum. Validate with `gen_bignum` fuzzing (already added) + the Integer
  fixtures.
- **Stage 2 — Strings/IO + OS capability.** Biggest LOC + biggest simplicity/safety win (`std::fs`/
  `std::process`). Validate with the `pass`/CLI fixtures + `pass-asan.sh`.
- **Stage 3 — Allocator + arenas + flat collections.** The contained-`unsafe` core; RAII for internal
  temporaries. Validate with `gen_arena`/`gen_array`/`gen_deep` fuzzing + `sanitize.sh`.
- **Stage 4 — Session scheduler + networking.** The hard concurrency piece (`pthread` → `std::thread`);
  the step-function call is the one genuine `unsafe` transmute. Validate with `session_run_*` fixtures +
  `tsan.sh` + `gen_session` fuzzing.

Once complete, the Cranelift backend can also link `axion-rt` (replacing its inline runtime) — **one Rust
runtime for all three backends**, retiring `runtime_backends_agree`'s drift concern.

## Cross-cutting requirements
- **ABI unchanged**: every export is `extern "C"` over i64 → the emitted IR and `codegen_tv.rs` are
  untouched.
- **`panic = "abort"`** in `axion-rt` (no unwinding across FFI).
- **`unsafe` is contained + commented**: each raw i64↔ptr / offset-load site documents the layout it
  mirrors (the size header at −8, the `[len][elems…]` collection layout).
- **Miri / `cargo-fuzz`** become available on the runtime crate — a new class of evidence the C never had.

## Verification (per stage + end-to-end)
- `scripts/sanitize.sh` (ASan/LSan over native fixtures), `scripts/fuzz.py` (interp-vs-native differential,
  now incl. `gen_bignum`/`gen_deep`), `scripts/tsan.sh` (sessions), `scripts/bench.sh --check` (perf
  baseline — watch for the lost-LTO regression), `cargo test` (backend agreement).
- `GUARANTEE.md`: move the runtime from "TRUSTED (hand-written C)" toward "mostly-safe Rust + small audited
  `unsafe`, Miri/fuzz-checked" — a direct shrink of the trusted base.

## Risks / open questions
- **Perf** from lost cross-lang LTO on hot flat-collection loops — measure early (Stage 3); if material,
  keep those few ops as inline-able or revisit LLVM-matched LTO.
- **`termios` no-echo** (`read_secret`) and a few syscalls may still want `libc`/`rustix` — a small,
  audited dependency, still far less unsafe surface than the whole C runtime.
- **Session scheduler** semantics must match exactly (Stage 4 is the riskiest); lands last, behind the
  full session fixture suite + TSan.
