# Axion

**Axion** is a systems functional language — **strict, linear, GC-free** — with
Haskell syntax, the memory determinism of Rust/C, and concurrency **free of data
races and deadlocks, proven by types**. The premise: unite the elegance of
Haskell with the control of C, without the garbage collector's safety net nor
manual *lifetimes*.

The compiler (`axionc`) is written **from scratch in Rust**. The master
specification lives in [`spec/Axion-V0.2.pdf`](spec/Axion-V0.2.pdf) (readable:
[`.html`](spec/Axion-V0.2.html)).

> **Status: publishable milestone — roadmap phases 0–3 (§17) complete and
> _validated_.** GC-free memory safety and type-safe concurrency, both measured,
> not merely claimed. See [Guarantees, with evidence](#guarantees-with-evidence).

## What runs today

```sh
cd axionc && cargo build            # pure cargo compiler (no LLVM build deps)
AX=axionc/target/debug/axionc

$AX examples/01_hello.axi           # Hello, Axion!
$AX examples/02_fib.axi             # 832040
$AX examples/03b_fizzbuzz.axi       # 1  2  Fizz  4  Buzz … FizzBuzz   (mapM_ + compose, NATIVE)
$AX examples/06_typeclasses.axi     # 6   (Eq a =>, monomorphized → zero-cost)
$AX --check examples/05_checksum_borrow.axi   # typecheck: linearity + Auto-Drop

# concurrency ACTUALLY RUNNING (session + spawn + channels, deadlock-free):
$AX axionc/tests/fixtures/session_run_pingpong.axi   # 42  (concurrent ping-pong 21→42)
```

Three executors for the same program, all in agreement:

| Mode | What |
|------|------|
| `axionc prog.axi` | **interpreter** (tree-walking) — the `--dev` *fast-path* |
| `axionc --backend cranelift prog.axi` | **`--dev`**: Cranelift JIT (machine code, no opt) |
| `axionc --release prog.axi` | **`--release`**: LLVM `-O2 -flto` + C runtime (competitive with C) |

The general-purpose core compiles **to native**: higher-order functions
(`map`/`filter`/`foldr`), **typeclasses** (with zero-cost monomorphization),
`compose`/partial application, and looping IO (`mapM_`, do-blocks). Native
**sessions** have started: `spawn`/`send`/`recv`/`close` lower to a cooperative
state machine and the concurrent ping-pong runs under `--backend cranelift`
(choice/cancellation and `--release` still interp-only) — see the roadmap.

`rustc`-style diagnostics (span + label + fix suggestion + JSON), with stable
codes: `axionc --explain AX0001`.

**New here?** Follow the guided tour [**Axion by Example**](docs/by-example.md)
— L0→L4, one concept at a time, every step runnable.

## Guarantees, with evidence

Not claims — **measurements**, under CI:

| Promise (spec §0) | Verified by |
|---|---|
| *No use-after-free, no double-free* | **AddressSanitizer** clean on all native fixtures (`scripts/sanitize.sh`) |
| *No memory leaks* | **LeakSanitizer**: `allocs == frees` on the proven subset |
| *Zero latency, C-level control* | benchmarks: **`--release` ≈ C `-O2`** on fib/loop/simd |
| *Zero-cost abstraction (generics)* | **monomorphized typeclasses** = hand-written C: dispatch **563 ≈ 564 (C) ≈ 561 (Rust trait)** ms |
| *No GC — release at static points* | the **arena crushes `malloc`** (~10×) and Rust's `Box` (~16×) in the allocation kernel |
| *Zero data races / deadlocks — by types* | linearity (race-freedom) + tree topology of `bound` (deadlock-freedom); anchored to a **formal calculus + CFSM model-checking** |
| *Faithful linearity* | **differential against GHC** (Linear Haskell) — same verdict in every scenario |

Benchmarks (ms, best of 3; same `clang` for C and Axion `--release` —
[`docs/benchmarks.md`](docs/benchmarks.md)):

```
kernel    Ax --rel |  C -O2  Rs -O2
fib            252 |    252     323      (parity)
loop           542 |    550     545      (parity)
alloc           32 |    316     495      (arena: ~10× > malloc, ~15× > Box)
simd            33 |     32      31      (parity)
dispatch       563 |    564     561      (monomorphized typeclass = zero-cost)
```

## How it works (architecture)

Its own pipeline, from scratch (no stage reuses GHC):

```
source → lexer(logos) → layout → parser → AST
       → check.rs   (linearity %1, Auto-Drop, arenas, sessions — the invariants live here)
       → infer.rs   (HM, Algorithm W)
       → core.rs    (Axion Core: strict, linear ANF IR; injects Auto-Drop)
       → interp.rs (--dev fast-path)  |  codegen.rs (Cranelift)  |  llvm.rs (LLVM --release)
```

- **GC-free memory (§2/§3):** *Auto-Drop* inserts `free` at static death points
  (local, cross-function, reclaimed borrows, in-place, and recursive **deep-drop**
  of nested structures); *arenas* with bulk reset and escape analysis.
- **Concurrency (§6/§9):** linear channels + *session types*; `bound` is a nursery
  whose acyclic topology gives deadlock-freedom by construction. The calculus is
  formalized in [`docs/phase-3-calculus.md`](docs/phase-3-calculus.md) **before**
  the code, with a reference interpreter and CFSM model-checking validating it.

More detail in [`docs/backend.md`](docs/backend.md) and the phase docs.

## Structure

| Path | Role |
|---------|-------|
| [`axionc/`](axionc/) | **The compiler**, from scratch in Rust. |
| [`spec/`](spec/) | The master specification, versioned alongside the code. |
| [`examples/`](examples/) | `.axi` programs (Hello, fib, FizzBuzz, typeclasses, linear buffer, Listing 2.1, borrows). |
| [`docs/by-example.md`](docs/by-example.md) | **Guided tour L0→L4** — the best entry point to learn. |
| [`docs/`](docs/) | Grammar, [error codes](docs/error-codes.md), [backend](docs/backend.md), [benchmarks](docs/benchmarks.md), [session calculus](docs/phase-3-calculus.md), phase checklists. |
| [`scripts/`](scripts/) | `sanitize.sh` (ASan/LSan), `differential.sh` (GHC oracle), `bench.sh`. |
| [`prototype/`](prototype/) | Throwaway EDSL bench from Phase 0 (validated linearity in Linear Haskell). |
| [`bench/`](bench/), [`differential/`](differential/) | Benchmark kernels; differential scenarios. |

## Testing

```sh
cd axionc && cargo test         # ~103 tests (integration + property + sessions)
cargo clippy --all-targets      # clean (-D warnings in CI)

# gates that need clang (AXION_CLANG, or clang on PATH):
AXION_CLANG=clang ../scripts/sanitize.sh      # ASan/LSan over the native runtime
../scripts/differential.sh                    # axionc vs GHC oracle (needs Nix)
```

## Roadmap (§17)

- **Phase 0 — Foundations** ✅ — strategy, repo, minimal subset, EDSL bench.
- **Phase 1 — Walking skeleton (L0/L1)** ✅ — `parse → typecheck → run`; three
  executors; records, sum types (parametric), closures, FFI, lists/L0.
- **Phase 2 — Memory model (the differentiator)** ✅ *and proven* — Auto-Drop,
  arenas, `%0.5`, deep-drop; sanitizers in CI.
- **Phase 3 — Concurrency** ✅ *proven, anchored, and running* — formal calculus →
  reference interpreter + model-checking → typechecker (`AX0300`–`AX0305`) →
  cooperative runtime (`bound`/`spawn`/channels/choice/cancellation).
- **Phase 4 — Ergonomics (LSP, teaching errors)** and **Phase 5 — ternary/advanced
  topology** — future.

**General-purpose (post-Phase 3, in progress).** Growing toward a Rust/Haskell,
calmly and tested, without breaking the philosophy:
- **Standard library** — lists (`map`/`filter`/`foldr`/`zipWith`/…), `++`, strings
  (`unlines`/`unwords`), user-defined infix operators.
- **Typeclasses** ✅ — `class`/`instance`, dispatch, static coherence
  (`AX0400`–`AX0405`), and **native codegen by monomorphization** (mono +
  constrained + transitive) — **zero-cost, measured** (see the `dispatch` benchmark).
- **Native IO/effects + first-class functions** ✅ — do-blocks, `mapM_`,
  `compose`/partial application, functions as values — all compile to native
  (FizzBuzz runs under `--release`). This is the **1st layer of the road to native
  M:N concurrency**.
- **Native sessions (Layer 2, cooperative) ✅** — `spawn`/`send`/`recv`/`close`,
  **choice** (`select`/`case offer`) and **cancellation** (`cancel`) lower to
  defunctionalized cooperative state machines over a native scheduler
  (`axion_sess_*`); ping-pong, offer and cancel run on **both** `--backend cranelift`
  and `--release` (LLVM), matching the interpreter, and are **ASan/LSan-clean**
  (the scheduler's nursery arena reclaims every task state — no leaks, no
  use-after-free). Next: **M:N** (worker threads + work-stealing + io_uring/epoll).

**Honesty about the state.** Known and documented debt: `Integer`/bignum missing
(`factorial 20` runs, `50` doesn't); **native sessions are cooperative
(single-thread), not yet M:N** — they run on both native backends and are
ASan/LSan-clean, but there are no worker threads / work-stealing / io_uring yet;
no `Float` yet; over-application (functions that return functions and are
re-applied) and mechanized metatheory (Iris/Actris) still to do. None is a
correctness hole — they are growth.

## Requirements

- **Rust** (stable rustc) for `axionc` — builds with pure `cargo`.
- **clang/LLVM** only at *runtime*, for `--release` and the sanitizers (`AXION_CLANG`
  or on PATH; e.g. `nix shell nixpkgs#llvmPackages_18.clang`).
- **Nix** (optional) for the GHC differential and the reproducible dev shell ([`flake.nix`](flake.nix)).
