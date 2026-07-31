-- Recursive session (§6, server loop): a worker whose protocol LOOPS. Each round
-- it offers a choice — `More` (handle one request: recv n, send n+1, then recurse)
-- or `Closed` (stop). The session type is recursive:
--   Rec (Offer (More (Recv Int (Send Int Loop))) (Closed End))
-- `Loop` refers back to the enclosing `Rec`, so `worker d4` (the tail call) closes
-- the protocol instead of reaching `close` — this is what AX0301 now permits for a
-- recursive tail. The client (`main`) drives three rounds (unrolled) then stops.
-- Increments: 10→11, 20→21, 30→31; sum = 63. Runs in the interpreter.
data Cmd = More (Ep End) | Closed (Ep End)

worker :: Ep (Rec (Offer (More (Recv Int (Send Int Loop))) (Closed End))) %1 -> IO ()
worker d = case offer d of
  More d2 -> do
    (n, d3) <- recv d2
    d4 <- send d3 (n + 1)
    worker d4
  Closed d2 -> close d2

main :: Int
main = bound $ do
  c <- spawn worker
  c1 <- select More c
  c1b <- send c1 10
  (r1, c1c) <- recv c1b
  c2 <- select More c1c
  c2b <- send c2 20
  (r2, c2c) <- recv c2b
  c3 <- select More c2c
  c3b <- send c3 30
  (r3, c3c) <- recv c3b
  c4 <- select Closed c3c
  close c4
  r1 + r2 + r3
