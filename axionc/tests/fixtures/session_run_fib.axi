-- Compute-heavy worker (subset widening for M:N): the session VALUE position now
-- admits calls to native top-level functions, so a worker can do real work
-- between channel ops. `worker` receives n and sends back `fib n` (naive, ~O(φ^n)
-- — genuine compute, not a constant). This is what a future M:N scheduler would
-- parallelise across cores. fib 20 = 6765. Same in all three executors.
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (fib n)
  close d3

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- send c 20
  (r, c3) <- recv c2
  close c3
  r
