-- parMap over a COMPUTED input list (§9): a real parallel map-reduce, not a
-- `replicate` of one value. `range 15 22` gives eight DISTINCT inputs [15..22];
-- `parMap worker` forks eight session workers (each computes `fib` of its input on
-- the M:N scheduler) and `sum` folds the replies. Exercises parMap with distinct
-- per-worker inputs and preserved input order. Sum of fib 15..22 = 45381.
-- Same in all three executors.
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (fib n)
  close d3

main :: Int
main = sum (parMap worker (range 15 22))
