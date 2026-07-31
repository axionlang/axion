-- Three-label external choice (§6): the worker offers three branches; `main`
-- selects the MIDDLE one (`Fast`). Each branch sends back a distinct value, so
-- the result observes which branch ran — proving the native 3-way tag dispatch
-- (not just a 2-way if/else). Fast sends 2 → main returns 2. Includes the
-- mandatory `Closed` branch (AX0303/T5). Same in all three executors.
data Resp = Live (Ep (Send Int End)) | Fast (Ep (Send Int End)) | Closed (Ep End)

worker :: Ep (Offer (Live (Send Int End)) (Fast (Send Int End)) (Closed End)) %1 -> IO ()
worker d = case offer d of
  Live d2 -> do
    d3 <- send d2 1
    close d3
  Fast d2 -> do
    d3 <- send d2 2
    close d3
  Closed d2 -> close d2

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- select Fast c
  (r, c3) <- recv c2
  close c3
  r
