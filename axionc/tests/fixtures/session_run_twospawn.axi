-- Two concurrent children (§11): `main` spawns two workers on separate channels,
-- sends each a number, then receives both doublings back. This exercises the
-- native generator's multi-suspension dispatch — `main$step` has TWO `recv`
-- suspensions, so `x` (from the first) must be saved/restored across the second.
-- worker doubles: 10→20, 11→22; x + y = 42. Same in all three executors.
worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (n + n)
  close d3

main :: Int
main = bound $ do
  a <- spawn worker
  b <- spawn worker
  a2 <- send a 10
  b2 <- send b 11
  (x, a3) <- recv a2
  (y, b3) <- recv b2
  close a3
  close b3
  x + y
