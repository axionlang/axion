-- Choice runtime (§6): the parent does `select Live`, the worker does `offer` and
-- dispatches to the Live branch, receives 99 and closes. A tagged sum value
-- (`Live (Ep …)`) carries the advanced endpoint. main returns 7.
data Resp = Live (Ep (Recv Int End)) | Closed (Ep End)

worker :: Ep (Offer (Live (Recv Int End)) (Closed End)) %1 -> IO ()
worker d = case offer d of
  Live d2 -> do
    (n, d3) <- recv d2
    close d3
  Closed d2 -> close d2

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- select Live c
  c3 <- send c2 99
  close c3
  7
