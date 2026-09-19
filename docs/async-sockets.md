# Async sockets: a real concurrent network server (scoping)

**Status:** scoping / approved-to-start. **Goal:** let Axión run a real concurrent TCP server —
one session worker per connection — that is **GC-free**, **data-race-free**, and **deadlock-free by
construction**, the capstone of the concurrency story. Today the M:N session scheduler is cooperative
and the `ax_net_*` ops are *blocking*, so a worker doing `ax_net_recv` stalls a whole pool thread;
you cannot `spawn` a handler per connection. This closes that gap.

## Feasibility (spiked, PASS)

A standalone probe (scratchpad, not committed) confirmed the make-or-break: a worker can do a
**non-blocking** socket read, PARK on the fd when it would block, let the scheduler run *other*
workers meanwhile (proven: a compute worker finished while the socket worker was parked), and RESUME
on readiness — a loopback echo round-tripped. The two enabling mechanisms both already exist in
skeleton: `SessGen` emits **suspension points** (`susp`/`resume`) for channel `recv`, and the
scheduler already parks/wakes via its `blocked` list. This work extends both to fds.

## Design decision (the crux — please confirm)

**Sockets are LINEAR fd resources with ASYNC (yielding) ops — not full session-dual-typed channels.**

- A `Sock` / `Listener` is a `%1` linear resource (an fd). Linearity gives **close-exactly-once**
  (Auto-Drop closes it at its death point) and **no sharing** ⇒ no data races on the socket.
- Its ops YIELD: `netAccept`, `netRecv`, `netSend` attempt the non-blocking syscall and, on
  `EWOULDBLOCK`, suspend the worker parked on the fd (resuming on readiness).
- **Not** dual-protocol-typed: a raw TCP byte stream has no fixed `Send`/`Recv` duality, and forcing
  one is awkward. The two guarantees don't need it — **deadlock-freedom** comes from the acyclic
  `bound` nursery topology (handlers are leaves off the acceptor; they don't channel each other), and
  **race-freedom** from `%1` linearity + the Mutex-guarded scheduler. A typed protocol layer *atop*
  `Sock` is a clean future extension, not a prerequisite.

Server shape this enables:

```haskell
handler :: Sock %1 -> IO ()            -- one linear connection, echo until close
handler s = case netRecv s of
  (msg, s2) -> if strLen msg == 0 then netClose s2
               else handler (netSend s2 msg)   -- recv/send YIELD; no thread blocked

main :: IO ()
main = bound $ acceptLoop (netListen 8080)     -- acceptLoop: accept (yields) → spawn handler → loop
```

## Stages (each independently verifiable; mirrors the C→Rust port's staging)

- **Stage 0 — non-blocking net ops (runtime). ✅ DONE.** `axion-rt` gained `ax_net_set_nonblocking`
  + `ax_net_wouldblock()` (the `i64::MIN` sentinel); `ax_net_accept`/`recv`/`send` return the
  sentinel on `EAGAIN`/`EWOULDBLOCK` instead of blocking (harmless for blocking fds — they never hit
  it, so the sequential server is unchanged), and `recv` keeps `""` (orderly close) distinct from the
  sentinel. Verified by `axionc/tests/net_nonblocking.rs` (hand-driven non-blocking loopback echo).
- **Stage 1 — scheduler fd-park + poll (runtime). ✅ DONE.** The scheduler `Inner` gained `fd_parked`
  + `polling`; a step that gets the sentinel calls `axion_sess_park_fd(sched, fd, want_write)` (stashed
  thread-locally, since steps run lock-free) and returns 0, and the worker routes it to `fd_parked`
  instead of the channel-`blocked` list. When nothing is runnable and only fd-parked tasks remain,
  one worker `poll`s the fd set (200 ms timeout) and re-readies the ready ones; deadlock is declared
  ONLY when channel-blocked tasks remain with **no** fd-parked tasks (so an acceptor waiting on the
  network never false-trips it). Race-free by construction: `fd_parked`/`polling` are touched only
  under the existing mutex, `poll` runs on an owned snapshot, `PARK_FD` is per-thread. Verified by
  `axionc/tests/sched_fd_park.rs` (a reader parks on a socket, `poll` wakes it on a background send).
  Whole-corpus TSan/ASan re-validated by CI's sanitize gates. *(Residual: the step budget still
  counts down over a server's lifetime — fine for the flagship, noted for production.)*
- **Stage 2 — `Sock`/`Listener` linear types + async op builtins (front-end). ✅ DONE.**
  `Sock`/`Listener` are `MUST_USE_PRIMS` (linear, no Drop — like `Ep`); `netConnect`/`netListen`/
  `netAccept`/`netRecv`/`netSend`/`netClose`/`netCloseL` are builtins (not prelude text → no oracle
  churn) registered in `infer.rs` (monomorphic types), `check.rs` (`builtins()` + `is_effectful` +
  `consumers`: recv/send/accept BORROW the socket = `Many`, close CONSUMES = `One`, so linearity
  forces **close-exactly-once**), and `interp.rs` (`net*` delegate to the libc `net_call_foreign`
  impls — `Sock`/`Listener` are i64 fds). Verified by `axionc/tests/net_sock.rs`: a `%1`-`Sock`
  handler round-trips against a background echo server on the interpreter, AND the checker rejects
  forgot-close (AX0002), double-close (AX0001), and use-after-close (AX0004). *(Enforcement covers a
  `Sock %1` PARAMETER — the handler pattern the flagship uses; a fresh un-threaded local from
  `netAccept`/`netConnect` isn't must-use-tracked, same as `Buffer`, which relies on the
  handler/scoped pattern. Native codegen of `net*` is Stage 3 — until then a `net*` program compiles
  only on the interpreter.)*
- **Stage 3 — `SessGen` socket-suspension-points (compiler).** Make each async socket op a suspension
  point: emit `attempt non-blocking op; on EWOULDBLOCK save resume + the fd and return
  blocked-on-fd; on resume, retry`. Reuses the existing `susp`/`resume`/state-block machinery
  (core.rs `SessGen`). Lower to the Stage-0 non-blocking runtime ops. Now handlers run natively on
  `--dev`/`--release`.
- **Stage 4 — the flagship + gates.** `examples/echoserver.axi` (or a small line-protocol server):
  accept loop spawns a session handler per connection. A **multi-client test harness** (connect N
  clients concurrently, assert all echoes) on all three backends; TSan on the scheduler; ASan/LSan
  for leak-freedom (each connection's `Sock` closed once, buffers reclaimed). Oracle snapshot for the
  new example (dump-oracle globs `examples/`).

## Critical files
- `axion-rt/src/lib.rs` — Stage 0 (non-blocking net ops + sentinel) and Stage 1 (scheduler fd-park +
  poll loop, `Inner` fields).
- `axionc/src/core.rs` (`SessGen`, `sess_layout`) — Stage 3 socket-suspension-points.
- `axionc/src/{infer,check,interp}.rs` + the prelude in `lib.rs` — Stage 2 `Sock`/`Listener` types +
  async op builtins (+ interp POSIX impls).
- `axionc/src/codegen.rs`, `llvm.rs` — register/declare the new runtime symbols if the ABI grows.
- `examples/echoserver.axi`, a multi-client harness (`scripts/` or a `run.rs` test) — Stage 4.

## Verification
- Per stage: Stage 0/1 Rust unit tests in `axion-rt` + `scripts/tsan.sh` (scheduler race-freedom);
  Stage 2 interp end-to-end; Stage 3 interp==`--dev`==`--release` on the handler; Stage 4 the
  multi-client harness + ASan/LSan (no leaked `Sock`/buffers) + TSan.
- Whole-repo gates stay green each stage: `cargo test`, `cargo clippy --all-targets -- -D warnings`,
  `./scripts/verify-gate.sh`, `./scripts/dump-oracle.sh` (re-snapshot the new example).

## Risks / open questions
- **Never-completing nursery** vs the scheduler's budget + "no-progress ⇒ deadlock" guards — must
  distinguish "all workers legitimately fd-parked, waiting on the network" from a real deadlock.
- **`spawn` with a `Sock` argument** — spawning a handler seeded with a linear `Sock` (like
  `spawn (server 0)` seeds params); confirm the linear `Sock` threads through `gen_spawn` cleanly.
- **TSan** on the new poll loop + parked-fd map (safe-Rust `Mutex`, but the poll interaction is new).
- **Fairness / starvation** among many fd-parked workers under one poll set (bounded, but note it).
- **Scope honesty:** this is the largest single feature of the arc — it touches the type system,
  checker, `SessGen`, the scheduler, and the net ops. It is a multi-session campaign; Stages 0–1 (all
  runtime) are the lowest-risk, highest-signal start.
