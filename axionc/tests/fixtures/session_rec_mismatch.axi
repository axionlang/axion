-- Must FAIL with AX0300: a recursive session tail call must continue the protocol
-- at the SAME session state as the function's parameter. Here `worker d3` recurses
-- while `d3` is still at `Send Int Loop` (the response was never sent), so it is not
-- at the recursion point (`Rec (Offer …)`) — a protocol-fidelity violation.
data Cmd = More (Ep End) | Closed (Ep End)

worker :: Ep (Rec (Offer (More (Recv Int (Send Int Loop))) (Closed End))) %1 -> IO ()
worker d = case offer d of
  More d2 -> do
    (n, d3) <- recv d2
    worker d3
  Closed d2 -> close d2

main :: Int
main = 0
