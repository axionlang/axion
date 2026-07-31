-- Cancellation runtime (§7, T5): the parent does `cancel c`, which sends `Closed`
-- to the peer; the worker does `offer` and receives `Closed`, taking the cancellation
-- branch. `Closed` is a normal protocol branch, not an exception. main returns 5.
data Resp = Live (Ep End) | Closed (Ep End)

worker :: Ep (Offer (Live End) (Closed End)) %1 -> IO ()
worker d = case offer d of
  Live d2 -> close d2
  Closed d2 -> close d2

main :: Int
main = bound $ do
  c <- spawn worker
  cancel c
  5
