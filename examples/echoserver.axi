-- echoserver.axi — a CONCURRENT TCP echo server, and the capstone of Axión's concurrency story:
-- a real network server that is GC-free, data-race-free, and deadlock-free BY CONSTRUCTION.
--
-- What it demonstrates — the whole thesis on a real workload (docs/async-sockets.md):
--   * CONCURRENT + GC-FREE: `serve` forks one `handler` per accepted connection onto the M:N
--     session-scheduler thread pool; the socket ops are ASYNC — `netAccept`/`netRecv` yield (park
--     the fd, resume on readiness via poll) instead of blocking a pool thread, so many connections
--     are in flight at once. Every allocation is reclaimed at a static point — no garbage collector.
--   * DATA-RACE-FREE BY CONSTRUCTION: `Sock` and `Listener` are LINEAR (`%1`) fd resources. Linearity
--     means no two tasks ever share a socket (no races), and it forces each socket to be CLOSED
--     EXACTLY ONCE — forgetting `netClose` is a compile error (AX0002), closing twice is AX0001,
--     and using a socket after close is AX0004. The type system, not a runtime, guarantees this.
--   * DEADLOCK-FREE BY CONSTRUCTION: the handlers are leaves forked inside the acyclic `bound`
--     nursery (a star off the acceptor — no handler waits on another), so the communication graph
--     is a tree and the checker rules out deadlock at COMPILE time.
--
-- Runs on `--dev` (Cranelift) and `--release` (LLVM): `serve` never returns, so the server runs
-- until it is killed, handling connections forever. Point a client at it: `nc 127.0.0.1 8080`.

-- One connection: echo the bytes back once, then close the socket (consumed exactly once).
handler :: Sock %1 -> IO ()
handler s = do
  msg <- netRecv s
  _ <- netSend s msg
  netClose s

-- The accept loop: wait for a connection (yields until one arrives), fork a handler for it, and
-- loop — forever. `l` (the Listener) threads through the tail call; the handlers run in parallel.
serve :: Listener %1 -> IO ()
serve l = do
  s <- netAccept l
  _ <- spawn (handler s)
  serve l

-- Open the listening socket inside the nursery, then hand it to the accept loop. `bound` confines
-- the nursery (deadlock-freedom); the server runs in PAR mode so it waits on every forked handler.
main :: Int
main = bound $ do
  l <- netListen 8080
  _ <- spawn (serve l)
  0
