-- Concurrency benchmark (Axion, session tasks on the M:N scheduler) — the same
-- fork-join workload as bench/conc.c and bench/conc.rs: four workers each compute
-- fib(N), the parent collects and sums. Unlike raw pthreads/std::thread, the
-- workers communicate over linear channels whose protocol is checked by types
-- (race-freedom + deadlock-freedom, no manual synchronization). `fib N` is fixed
-- at 34 here to match `conc.c 34` / `conc.rs 34`; set AXION_SESS_THREADS to vary
-- the worker-thread count. Result: 4 × fib 34 = 22811548.
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
