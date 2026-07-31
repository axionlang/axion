-- Parallel workload (the M:N target): `main` spawns FOUR independent workers,
-- each computing `fib 25` on its own channel, then collects and sums the four
-- results. On a single-thread cooperative scheduler the four computations run one
-- after another; under M:N they run on separate cores in parallel. The RESULT is
-- deterministic either way (session types ⇒ no races): 4 × fib 25 = 4 × 75025 =
-- 300100. Same in all executors.
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
  a2 <- send a 25
  b2 <- send b 25
  c2 <- send c 25
  e2 <- send e 25
  (ra, a3) <- recv a2
  (rb, b3) <- recv b2
  (rc, c3) <- recv c2
  (re, e3) <- recv e2
  close a3
  close b3
  close c3
  close e3
  ra + rb + rc + re
