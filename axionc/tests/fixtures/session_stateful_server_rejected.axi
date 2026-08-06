-- Stateful recursive server loop — documents a session-recursion LIMITATION.
-- This is a realistic request/response service: the server keeps a running total
-- across the `offer` loop (`Add` accumulates, `Total` returns the sum, `Closed`
-- cancels). But it is REJECTED with AX0301: the recursive-tail recognizer
-- (`sess_tail_call` in check.rs) only accepts `f d` — the endpoint as the SOLE
-- argument — so the accumulator-carrying tail `server (acc + n) d3` is not seen as
-- continuing the protocol, and `d3` is reported as never reaching `close`.
--
-- So server-side state cannot be threaded across a recursive session loop today.
-- The fix (scoped) generalizes `sess_tail_call` to find the endpoint among several
-- args, and updates the native `gen_tail` (core.rs) + the interp recursive-tail
-- step to store the extra accumulator params before looping. Kept here as a
-- rejection fixture until that lands.
data Cmd = Add (Ep (Recv Int Loop)) | Total (Ep (Send Int End)) | Closed (Ep End)

server :: Int -> Ep (Rec (Offer (Add (Recv Int Loop)) (Total (Send Int End)) (Closed End))) %1 -> IO ()
server acc d = case offer d of
  Add d2 -> do
    (n, d3) <- recv d2
    server (acc + n) d3
  Total d2 -> do
    d3 <- send d2 acc
    close d3
  Closed d2 -> close d2

main :: Int
main = bound $ do
  c <- spawn (server 0)
  c1 <- select Add c
  c1b <- send c1 10
  c2 <- select Add c1b
  c2b <- send c2 20
  c3 <- select Total c2b
  (tot, c4) <- recv c3
  close c4
  tot
