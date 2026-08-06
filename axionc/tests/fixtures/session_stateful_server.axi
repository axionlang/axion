-- Stateful recursive server loop — a realistic request/response service that keeps
-- a running total across the `offer` loop (`Add` accumulates, `Total` returns the
-- sum, `Closed` cancels). The accumulator is threaded through the recursive tail
-- `server (acc + n) d3`.
--
-- STATUS: TYPE-CHECKS (`--check` clean). `sess_tail_call` (check.rs) now recognizes
-- the endpoint as the LAST argument, so the accumulator-carrying tail is accepted as
-- continuing the protocol (previously AX0301). It does NOT RUN yet: `spawn (server 0)`
-- passes a partially-applied worker, and the recursive tail must store the extra
-- accumulator params before looping — the interp step + native `gen_tail` (core.rs)
-- don't handle either yet. Once they do, `main` drives Add 10, Add 20, Total → 30.
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
