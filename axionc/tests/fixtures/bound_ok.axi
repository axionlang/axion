-- Well-confined nursery (§9): creates a pair of endpoints inside the `bound` and
-- consumes both in there (`close`). Nothing escapes → the communication graph is
-- a tree (deadlock-freedom by construction). Accepted.
main :: IO ()
main = bound $ do
  (c, d) <- newChannel
  close c
  close d
