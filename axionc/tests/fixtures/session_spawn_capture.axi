-- AX0305: the closure passed to `spawn` captures the endpoint `a` from outside. Two
-- children could then share channels and form a cycle → deadlock. A child can only
-- communicate with the parent through its endpoint parameter (tree topology, §9).
main :: Int
main = bound $ do
  (a, b) <- newChannel
  c <- spawn (\d -> send a 1)
  close b
  close c
  0
