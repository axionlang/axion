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

### N = 50 connections × 500 round-trips (25 000 echoes/trial)

| server | throughput (echo/s) | p50 (µs) | p99 (µs) |
|--------|--------------------:|---------:|---------:|
| C (pthread/conn)      | 360,241 | 99 | 276 |
| Rust (thread/conn)    | 360,871 | 98 | 267 |
| Haskell (forkIO)      | 281,628 | 88 | 1,309 |
| **Axión (M:N session)** | **319,619** | **89** | **1,044** |

### N = 200 connections × 200 round-trips (40 000 echoes/trial)

| server | throughput (echo/s) | p50 (µs) | p99 (µs) |
|--------|--------------------:|---------:|---------:|
| C (pthread/conn)      | 342,261 | 188 | 695 |
| Rust (thread/conn)    | 336,933 | 185 | 769 |
| Haskell (forkIO)      | 289,394 | 118 | 3,290 |
| **Axión (M:N session)** | **334,849** | **245** | **4,985** |

## Honest reading

- **Throughput: Axión is competitive.** ~89% of C/Rust at N=50 and ~98% at N=200, and it beats GHC's
  green-thread server on throughput at both loads. For a young language whose runtime is a from-scratch
  Rust M:N scheduler, matching hand-tuned C/Rust echo throughput is a strong result.
- **Tail latency (p99) is Axión's weak spot, and it's a known scheduler-maturity issue, not a design
  flaw.** The scheduler uses a **single `poll()` poller** over all parked fds (O(n) per wakeup) and
  **one global `Mutex`** for all task-state transitions. Under high fan-out (N=200) that shows as a
  fat tail (≈5 ms p99). The obvious fixes — `epoll` instead of `poll`, multiple pollers / sharded
  readiness, finer-grained locking — are runtime engineering, orthogonal to the safety guarantees.
  (GHC, with a mature epoll manager, still shows a fat tail here too — tail latency under this model
  is hard.)
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
