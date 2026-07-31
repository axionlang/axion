-- Compute-bound session workload for the M:N scaling benchmark
-- (scripts/session-scaling.sh): four independent workers each computing `fib 34`
-- (~5.7M calls), the parent sums the four results. Almost no channel traffic
-- (one exchange per worker) and heavy per-task compute → the ideal case for the
-- thread pool. Run with AXION_SESS_THREADS=1/2/4/8 to see near-linear speedup up
-- to the number of workers. Result: 4 × fib 34 = 4 × 5702887 = 22811548.
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (fib n)
  close d3

main :: Int
main = bound $ do
  a <- spawn worker
  b <- spawn worker
  c <- spawn worker
  e <- spawn worker
  a2 <- send a 34
  b2 <- send b 34
  c2 <- send c 34
  e2 <- send e 34
  (ra, a3) <- recv a2
  (rb, b3) <- recv b2
  (rc, c3) <- recv c2
  (re, e3) <- recv e2
  close a3
  close b3
  close c3
  close e3
  ra + rb + rc + re
