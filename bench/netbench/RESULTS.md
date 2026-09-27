# Concurrent echo-server benchmark — Axión vs Rust vs C vs Haskell

A **fair, apples-to-apples** comparison of a concurrent keep-alive TCP echo server written in each
language, driven by one identical load generator. The point is to place Axión — a GC-free language
whose memory-safety, data-race-freedom, and deadlock-freedom are guaranteed at **compile time** —
against mature runtimes on a real network workload.

## What each server is

Every server accepts connections and, per connection, loops `recv` → echo the bytes → until the peer
closes. Each uses its language's **idiomatic lightweight concurrency**, one unit per connection:

| Language | Concurrency model | Build |
|----------|-------------------|-------|
| C        | one `pthread` per connection, blocking `recv`/`send` | `clang -O2` |
| Rust     | one `std::thread` per connection, blocking `read`/`write` | `rustc -O` |
| Haskell  | one `forkIO` green thread per connection, GHC epoll IO manager | `ghc -O2 -threaded` (`+RTS -N`) |
| Axión    | one M:N **session task** per connection (`spawn`), async socket ops that park the fd | `axionc --release` (LLVM) |

Sources: `echo.c`, `echo_rust.rs`, `echo.hs`, `echo_axion.axi`. The Axión server is
`examples/echoserver.axi` verbatim (verifier-clean: 0 corruption, 0 leaks).

## Load generator (`loadgen.rs`, identical for all four)

`N` concurrent keep-alive connections, each doing `R` request/echo round-trips of a 32-byte message;
records per-request latency; reports throughput (echoes/sec over wall time) and p50/p99. Median of 3
trials after a discarded warm-up. Loopback, `TCP_NODELAY` on both ends.

## Results

`./run.py <N> <R> <msgbytes> <trials>` — measured on this dev machine (`rustc 1.95`, `clang 21`,
`GHC 9.10.3`); absolute numbers are machine-specific, the **ratios** are the point.

Axión numbers below are with the **epoll + sharded-readiness** scheduler (see "Tail-latency work").

### N = 50 connections × 500 round-trips (25 000 echoes/trial)

| server | throughput (echo/s) | p50 (µs) | p99 (µs) |
|--------|--------------------:|---------:|---------:|
| C (pthread/conn)      | 338,864 | 106 | 291 |
| Rust (thread/conn)    | 316,500 | 95 | 395 |
| Haskell (forkIO)      | 261,087 | 85 | 1,455 |
| **Axión (M:N session)** | **315,404** | **106** | **962** |

### N = 200 connections × 200 round-trips (40 000 echoes/trial)

| server | throughput (echo/s) | p50 (µs) | p99 (µs) |
|--------|--------------------:|---------:|---------:|
| C (pthread/conn)      | 313,339 | 141 | 1,088 |
| Rust (thread/conn)    | 309,205 | 155 | 772 |
| Haskell (forkIO)      | 265,023 | 121 | 3,073 |
| **Axión (M:N session)** | **305,818** | **397** | **2,011** |

*(The machine is shared/noisy — absolute p99 swings run-to-run by ±50% even for C — so read these as
representative, and the tail comparison below as the robust signal.)*

## Tail-latency work: epoll + sharded readiness

The **first** version of the scheduler detected socket readiness with a single `poll()` that ran only
when no worker was computing (`running == 0`). Under sustained load that starves the poller — workers
are almost always busy — so ready fds pile up and the p99 tail blew out to **≈5 ms at N=200**. The
root cause was architectural (poll/compute non-overlap), not `poll` vs `epoll` per se.

The fix: a **persistent `epoll` instance sharded across K dedicated I/O threads** (K = `cores/2`,
capped at 4; `AXION_NET_SHARDS` overrides). Each shard thread blocks in `epoll_wait` **concurrently
with the compute workers**, so readiness is never starved; a ready batch is re-readied under one lock
acquisition (not one per fd) and hands off to workers via the condvar. Effect at N=200:

| Axión scheduler | p50 (µs) | p99 (µs) |
|-----------------|---------:|---------:|
| single `poll()` (starved)     | 245 | **≈4,985** |
| epoll + sharded (this version) | 397 | **≈1,500–2,000** |

The **p99 tail is cut ~2.5–3×** — the pathological fat tail is gone. The remaining gap to C/Rust is now
roughly **uniform** (~2× on both p50 and p99).

### Is the global mutex the next lever? Measured: **no.**

The obvious hypothesis was that the single `Mutex<Inner>` serialising every task-state transition was
the ceiling, so the next step would be to shard it. A worker-count sweep (N=200, `AXION_SESS_THREADS`)
disproves that — throughput *scales up* with workers and p50 *drops*, then flattens at the core count:

| workers | throughput | p50 | note |
|--------:|-----------:|----:|------|
| 1 | ~130k | ~970 µs | worker-bound |
| 2 | ~195k | ~700 µs | |
| 4 | ~235k | ~530 µs | |
| 8 | ~245k | ~470 µs | flattens (= 8 cores) |
| 12 | ~230k | ~510 µs | *oversubscription*, not lock-collapse |

Lock contention would make throughput **plateau or collapse** as workers rise; instead it climbs to
core-saturation and only dips when threads oversubscribe the 8 cores. **The mutex is not the
bottleneck.** The remaining ~2× is the intrinsic **per-request coordination cost of the M:N model** —
every socket wakeup crosses an epoll-thread → worker hand-off (condvar) plus a `SessGen` step
save/restore, work that thread-per-connection C/Rust simply don't do (the same OS thread blocks in
`recv` and continues on its own stack). Closing it would mean removing the epoll→worker hand-off — so that was spiked next.

### Spiked and rejected: "run-on-reactor" affinity

The obvious hand-off fix: let the epoll shard thread **run the ready socket step itself** (recv/echo/
re-park loop) instead of waking a worker — a connection's whole keep-alive lifecycle then stays on
one thread, hand-off- and condvar-free. Implemented as a spike and measured (K = shard count):

- At low concurrency (N=50) p50 matched C/Rust (~85 µs). But
- it **regressed throughput ~13%** (≈306k → ≈265k, i.e. 95% → ~78% of C/Rust) and did **not** improve
  p99. Cause: a reactor thread runs *its* shard's ready fds **serially inline**, whereas the hand-off
  model's shared ready queue lets **all** workers grab **any** ready task — better load-spreading that
  outweighs the hand-off cost. No free lunch: the hand-off buys work-balancing.

So the run-on-reactor change was **reverted** — the hand-off design is better. The lesson (again):
the residual ~2× is not a single removable bottleneck; it is the M:N shared-scheduler model's
coordination + load-balancing machinery vs thread-per-connection's zero-coordination, perfectly
parallel (one OS thread per connection) model. At *moderate* load (N=50) Axión is already near parity
(p50 ~104 vs ~100, ~94% throughput); the gap only opens at high fan-out, and it is the price of the
model that makes the server GC-free and memory/race/deadlock-safe *at compile time*. Neither sharding
the mutex nor running on the reactor moves it; the only thing that would is abandoning the shared M:N
scheduler for a pinned per-core runtime with work-stealing — a large, risky rewrite whose payoff the
spike suggests is small. Not worth it.

## Honest reading

- **Throughput: Axión is competitive** — ~93–99% of C/Rust at both loads, and it beats GHC's
  green-thread server. For a young language whose runtime is a from-scratch Rust M:N scheduler,
  matching hand-tuned C/Rust echo throughput is a strong result.
- **Tail latency: the fat tail is fixed; a uniform ~2× latency gap remains** — and a worker-count
  sweep shows it is *not* the mutex (throughput scales with cores, no contention collapse; see above),
  but the intrinsic per-request coordination of the M:N model vs zero-coordination thread-per-conn.
  It is the price of the model that makes the server GC-free and memory/race/deadlock-safe at compile
  time. (GHC's mature epoll manager still shows a fatter tail here — tail latency under this model is hard.)
- **What Axión gives up nothing on:** the server is GC-free, and the compiler *proved* — before it
  ran — that no socket leaks, no double-close, no use-after-close (linear `Sock`, AX0002/AX0001/AX0004),
  no data race (linearity + the Mutex scheduler), and no deadlock (acyclic `bound` nursery). C and
  Rust here get none of that for free; Haskell gets memory safety but not the linear-resource or
  deadlock guarantees, and pays the GC.

## Reproduce

```sh
cd bench/netbench
rustc -O echo_rust.rs -o echo_rust
cc -O2 echo.c -o echo_c -lpthread
ghc -O2 -threaded -rtsopts echo.hs -o echo_hs
../../axionc/target/debug/axionc --release -o echo_axion echo_axion.axi
rustc -O loadgen.rs -o loadgen
./run.py 50 500 32 3
```
