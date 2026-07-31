# Session M:N scaling — when does the global mutex matter?

Objective data for the **work-stealing decision** (Layer 2b-3). The M:N session
scheduler (§11) runs tasks on a thread pool and guards all shared state (channel
buffers + the ready/blocked queues) with **one global mutex**, held for each
channel op. Work-stealing (lock-free deques instead of the mutex) is the standard
next optimization — but it only pays off once a workload can *saturate* that lock.
This note measures whether one can.

Reproduce: `AXION_CLANG=<clang> ./scripts/session-scaling.sh` (8-core box below).

## 1. Compute-bound scales (the thread pool works)

`bench/sess_compute.axi` — four workers each computing `fib 34`, one channel
exchange each. Wall time vs `AXION_SESS_THREADS`:

| threads | wall | speedup |
|--------:|-----:|--------:|
| 1 | 0.062s | 1.0× |
| 2 | 0.031s | 2.0× |
| 4 | 0.017s | 3.6× |
| 8 | 0.026s | (only 4 workers — no more parallelism) |

Near-linear up to the worker count. The scheduler is not in the way when tasks do
real work between channel ops.

## 2. The global-mutex ceiling (`bench/sess_mutex.c`)

N threads hammering the scheduler's critical section (lock; tiny queue push+pop;
unlock) — a channel op with zero compute between ops:

| threads | contended rate | ns/op |
|--------:|---------------:|------:|
| 1 | 62.8 M ops/s | 15.9 |
| 2 | 13.6 M ops/s | 73.4 |
| 4 | 14.0 M ops/s | 71.3 |
| 8 | 9.8 M ops/s | 101.6 |

Two things: the lock tops out around **10–14 M channel-ops/s** under contention,
and going 1→2 threads is a **~4× slowdown** — for a purely channel-bound workload
the current M:N scheduler would be *slower* than single-threaded.

## Conclusion: work-stealing is premature (no workload can reach the ceiling)

To be capped by the mutex a program must **sustain** channel-op rates near
10 M ops/s. No expressible Axion session can, for two structural reasons:

1. **No recursion in session bodies** (server loops are out of the native subset),
   so a task does a *fixed, small* number of channel ops — there is no long-running
   channel loop.
2. **The generator's resume-region duplication is O(N²)** in the suspension count.
   A fan-in of N workers needs N `recv`s in `main`, and each resume region
   re-emits the continuation from its suspension onward. Measured IR blow-up:

   | workers (N) | LLVM IR lines |
   |------------:|--------------:|
   | 20 | 52,962 |
   | 40 | 367,832 |
   | 60 | 1,185,502 (compile times out) |

   So a channel-heavy fan-in is capped at N ≈ 20–30 → a few hundred channel ops →
   **microseconds**, six orders of magnitude below the ceiling.

**Decision:** defer work-stealing. It optimizes a bottleneck nothing can hit yet —
the same "build for a real workload" pattern as M:N before the subset was widened,
and as io_uring (no async I/O exists). The real prerequisites, in order, are:

1. **Recursion in session bodies** (`worker d = do { … ; worker d' }`) — lets a
   task loop over channel ops, i.e. a server / pipeline stage. This is what makes
   a *sustained* channel-op rate expressible at all.
2. **Fix the O(N²) resume-region duplication** (share suspension continuations
   instead of re-emitting them) — lets fan-in/fan-out scale.

Only with (1)+(2) can a benchmark actually push the scheduler to the mutex
ceiling; then the numbers above say exactly how much work-stealing would buy
(roughly: turn the 1→2-thread *slowdown* into a speedup, and lift the ~10 M ops/s
cap). Until then the single global mutex is correct, ThreadSanitizer-clean
(`scripts/tsan.sh`), and not on any expressible critical path.
