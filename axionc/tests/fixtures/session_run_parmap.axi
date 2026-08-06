-- Structured fork-join via `parMap` (§9): the SAME parallel workload as
-- `session_run_parfib.axi` (four workers, each computing `fib 25`, summed), but
-- the repetitive spawn/send/recv/close is collapsed into a single `parMap` call.
-- `replicate 4 25` produces the four inputs; `parMap worker` opens its own nursery,
-- forks one worker per input, sends each input, and collects the four replies as a
-- List (in input order); `sum` folds them. Deterministic (session types ⇒ no races):
-- 4 × fib 25 = 4 × 75025 = 300100 — identical to the hand-unrolled version.
-- (Runs on the cooperative interpreter today; native M:N lowering is a follow-up.)
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (fib n)
  close d3

main :: Int
main = sum (parMap worker (replicate 4 25))
