-- Concurrency benchmark, `parMap` form (§9) — the SAME fork-join workload as
-- bench/conc.axi (four workers each compute fib 34, the parent sums = 22811548),
-- but the hand-unrolled spawn/send/recv/close is collapsed into one `parMap`.
-- `parMap` opens its own nursery, forks one worker per input onto the same M:N
-- scheduler, and collects the replies as a List — identical runtime behaviour and
-- parallelism to conc.axi, far less boilerplate. `fib N` fixed at 34 to match
-- conc.c/conc.rs; AXION_SESS_THREADS sets the worker-thread count.
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (fib n)
  close d3

main :: Int
main = sum (parMap worker (replicate 4 34))
