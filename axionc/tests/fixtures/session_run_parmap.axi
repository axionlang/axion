-- Structured fork-join via `parMap` (§9): the SAME parallel workload as
-- `session_run_parfib.axi` (four workers, each computing `fib 25`, summed), but
-- the repetitive spawn/send/recv/close is collapsed into a single `parMap` call.
-- `replicate 4 25` produces the four inputs; `parMap worker` opens its own nursery,
-- forks one worker per input, sends each input, and collects the four replies as a
-- List (in input order); `sum` folds them. Deterministic (session types ⇒ no races):
-- 4 × fib 25 = 4 × 75025 = 300100 — identical to the hand-unrolled version.
-- Runs on all three executors (interp + cranelift + llvm), reclaiming exactly.
--
-- LIMITATIONS (both deferred until a real use case needs them):
--   * The worker must be a NAMED top-level session function — an inline lambda
--     runs under the interpreter but not natively (Op::Unsupported), because the
--     native path monomorphizes on the concrete worker to emit `worker$step`.
--   * The reply List is reclaimed by the flat `axion_drop_List` (cons cells only),
--     so scalar replies (Int/Float) reclaim exactly, but a worker returning a HEAP
--     payload (List, record) leaks the payloads — same as any polymorphic `List`
--     result. Fix: key the result at its concrete element type (reuse the
--     `axion_drop_List$T` mono-destructors) instead of the generic "List".
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (fib n)
  close d3

main :: Int
main = sum (parMap worker (replicate 4 25))
