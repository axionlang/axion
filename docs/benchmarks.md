# Benchmarks (§13) — Axion vs C vs Rust

> The spec is explicit: the performance guarantees are **design, not measurement**
> — they stay "under benchmark" (§13, §0). We measure **both** Axion backends:
> `--dev` (Cranelift, fast-path §11) and `--release` (LLVM `-O2 -flto`, §18).

## Methodology

- Five kernels, the same algorithm in each language (`bench/<kernel>.{axi,c,rs}`):
  - **fib** — naive recursive `fib(40)` (compute / branches).
  - **loop** — 200 M arithmetic iterations with `mod` (not closable by `-O2`). In
    Axion it is recursion (no loops in the language); in C/Rust it is an idiomatic loop.
  - **alloc** — 40 M allocations. In Axion via an **arena** (§3, bump + bulk reset);
    in C via `malloc`/`free`, in Rust via `Box` — each language's idiom.
  - **simd** — vectorizable reduction over an array (200 M adds). In Axion via the
    `sumBytes` primitive over a linear `Buffer U8` (§4/§5) — the vectorizable
    *escape-hatch* (a runtime loop that `clang -O2` vectorizes and `-flto` inlines);
    in C/Rust it is the idiomatic loop that `-O2` auto-vectorizes.
  - **dispatch** — 200 M steps where the hot operation is a **typeclass method**.
    In Axion, `inner :: Stepper a =>` is generic and **monomorphization** specializes
    it to `inner$Int` with `step → step$Int`, which LLVM inlines; in **Rust** it is
    generic via a *trait* (Rust monomorphizes by the same mechanism); in C it is the
    direct hand-written call. It measures **zero-cost abstraction** — does the
    generic pay the same as the hand-written one?
- Harness: [`scripts/bench.sh`](../scripts/bench.sh) — best of 3, `date +%s%N`, and
  it checks that, per kernel, every variant produces the same result.
- **Comparable tier:** the **same `clang` (LLVM)** compiles the C and the Axion
  `--release` (both `-O2 -flto`); Rust is `rustc` (also LLVM). The Axion `--dev`
  time includes parse+typecheck+JIT (~ms), negligible.
- **`-flto` is fair, not a trick:** measured, `-flto` **does not change** the C
  times on any kernel (fib/loop are a single compilation unit; in `alloc`,
  `malloc`/`free` live in libc, outside any LTO — so they don't inline with or
  without `-flto`). The arena's advantage is **structural** (inlinable
  bump-allocator vs a general heap allocator in libc), not a flags artifact.

## Result (one machine, 8 cores; indicative, not definitive)

```
Times (ms, best of 3):
  kernel    Ax --dev Ax --rel |   C -O0   C -O2 |  Rs -O0  Rs -O2
  --------  -------- -------- |   -----   ----- |  ------  ------
  fib            666      252 |     590     252 |     840     323
  loop          3159      542 |    2243     550 |    2440     545
  alloc         1493       32 |     330     316 |    1085     495
  simd          1914       33 |     338      32 |     710      31
  dispatch      3488      563 |    2433     564 |    2485     561
```

## Reading

- **Compute and loops — parity with C.** On `fib` (252 ms) and `loop` (542 ms),
  Axion `--release` is **on par with C `-O2`** (252 / 550) and Rust `-O2` (323 /
  545). It lowers to the same LLVM, with essentially identical IR; `--release` does
  TCO of the `loop` recursion into a real loop.
- **Allocation — the arena wins.** The arena model (§3) reclaims in bulk: 40 M
  cells in **32 ms**, versus C `-O2`'s `malloc`/`free` (316 ms, **~10×**) and Rust
  `-O2`'s `Box` (495 ms, **~15×**). `-flto` links the C runtime in the same
  compilation and **inlines the bump-allocator** into the hot loop. It is exactly
  the scenario where Axion's memory model should shine — and where choosing a **C
  runtime with `-flto`** (rather than a non-inlinable Rust `staticlib`) pays off.
- **SIMD — parity (gap closed).** The `sumBuffer` primitive over a `Buffer` (§4) is
  a runtime loop that `clang -O2` **auto-vectorizes** and `-flto` **inlines** into
  the caller: **33 ms**, on par with C `-O2` (32) and Rust (31). This is how a
  functional language exposes SIMD — via vectorizable bulk-data primitives (the
  "imperative escape-hatch" of §4), not via user loops.
- **Typeclasses — zero-cost abstraction, à la Rust.** On `dispatch`, the class
  method in the hot loop, monomorphized and inlined by LLVM, costs **563 ms** — on
  par with C `-O2` calling the function by hand (**564 ms**) and with Rust `-O2`
  generic via *trait* (**561 ms**), within **3 ms** of each other. The generic
  **pays nothing** for being generic: it is exactly the promise "elegance of
  Haskell, control of Rust". The specialization is the same mechanism as Rust
  (monomorphization), not dictionary passing with indirection.
- **`--dev` is the fast-path, not the fast one.** Without optimizations or TCO, it
  pays for the recursion in `loop` (3159 ms), the opaque runtime call in `alloc`
  (1493 ms), and the **non-vectorized** `sumBuffer` of axionc's debug Rust runtime
  in `simd` (1914 ms). Its role is to compile **instantly** for the edit-run cycle;
  performance lives in `--release`.

This confirms the premise of the **two backends** (§11/§18): Cranelift for the
instant edit-run cycle, LLVM for performance competitive with C in release.

## Concurrency (§11) — Axion sessions vs raw C/Rust threads

A fork-join workload (`bench/conc.{axi,c,rs}`): **4 workers each compute `fib 34`,
the parent sums** (= 22811548). C uses **pthreads**, Rust uses **std::thread** —
raw, unchecked threads; Axion uses **session tasks on the M:N scheduler**, where
the workers talk over linear channels whose protocol is checked by types
(race-freedom + deadlock-freedom, no manual locks). Wall time (best of 9, same
`clang -O2` for C and Axion `--release`), 1 vs 4 worker threads:

```
  language           1 thread  4 threads  speedup
  C (pthreads)         0.059s     0.016s     3.7×
  Rust (threads)       0.067s     0.018s     3.7×
  Axion --release      0.062s     0.017s     3.6×
```

- **Single-thread compute — parity.** ~0.06 s in all three: Axion's `fib` lowers to
  the same LLVM as C/Rust, and running the four workers on one scheduler thread is
  the same total work. (Fairness note: the C/Rust sequential path needs `volatile`/
  `black_box` so `-O2` doesn't hoist the four identical `fib` calls to one — Axion
  can't be so optimized because each `34` arrives over a channel.)
- **Parallel scaling — parity.** Axion reaches **3.6×** on 4 cores, essentially the
  same as raw pthreads (3.7×) and std::thread (3.7×): at coarse granularity the
  `fib` compute dominates and the scheduler/channel overhead is negligible. Axion
  gets the type-checked race- and deadlock-freedom **for free** here.
- **Where the overhead would show:** a *channel-bound* workload (many small messages)
  would hit the scheduler's global mutex (~10–14 M ops/s, [`session-scaling.md`](session-scaling.md)) —
  that is the frontier work-stealing addresses, not reachable by coarse compute.

Harness: [`scripts/concurrency-bench.sh`](../scripts/concurrency-bench.sh)
(`AXION_SESS_THREADS` sets Axion's worker-thread count). Numbers vary run-to-run;
the parity, not the third decimal, is the point.

## Reproduce

```sh
AXION_CLANG=/path/to/clang ./scripts/bench.sh              # single-thread kernels
AXION_CLANG=/path/to/clang ./scripts/concurrency-bench.sh  # fork-join: C/Rust/Axion
AXION_CLANG=$(nix eval --raw nixpkgs#llvmPackages_18.clang)/bin/clang \
  RUNS=5 ./scripts/bench.sh
```

`--release` (and the C baseline) need `clang` — via `AXION_CLANG` or on PATH
(e.g. `nix shell nixpkgs#llvmPackages_18.clang`).

## Limitations / to do

- `Buffer U8` is **linear** (`%1`, must-use), with in-place (`bufIota`/
  `xorInPlace`), reading (`sumBytes`) and `free` — enforced by the typechecker
  (consume 2× → AX0001; drop → AX0002). Missing is the surface **sugar**
  (`imperative $ do`, `$`, `foldBytes (+)` with operator sections) and `withBuffer`
  as a bracket — to run `examples/03`/`05` verbatim.
- Synthetic kernels; larger mixed workloads and I/O are missing.
- Numbers vary by machine/load; use as order of magnitude, not absolutes.
