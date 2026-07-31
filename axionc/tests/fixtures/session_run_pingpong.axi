-- Session runtime (§11): a CONCURRENT program that runs. The `bound` opens a
-- nursery; `spawn worker` forks a child linked by a channel; the parent sends 21, the
-- worker receives, doubles (42) and returns, the parent receives and returns 42. The
-- cooperative scheduler (tasks = defunctionalized continuations) switches on an empty `recv`.
worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (n + n)
  close d3

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- send c 21
  (r, c3) <- recv c2
  close c3
  r
