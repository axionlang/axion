-- Heap values sent over a channel are owned by the receiver, which frees them. A fresh value
-- moves with the send; one the sender does not own (`same s` may return its argument) is sent as
-- a copy, so the sender still frees its own. A received value handed to another task moves with
-- it; one received into `_` is freed at once. These values all leaked before.
-- main sends "t7" and "t8"; worker keeps "t7", drops "t8", hands "t7" to `reply`, which sends
-- back a copy of it and frees its own. The answer is strLen "t7" + strLen "t7!" = 2 + 3 = 5.
tagOf :: Int -> String
tagOf n = strAppend "t" (showInt n)

same :: String -> String
same s = if strLen s > 100 then strAppend s "" else s

shout :: String -> String
shout s = strAppend s "!"

reply :: String -> Ep (Send String (Send String End)) %1 -> IO ()
reply s d = do
  d2 <- send d (same s)
  d3 <- send d2 (shout s)
  close d3

worker :: Ep (Recv String (Recv String (Send String (Send String End)))) %1 -> IO ()
worker d = do
  (s, d2) <- recv d
  (_, d3) <- recv d2
  reply s d3

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- send c (tagOf 7)
  c3 <- send c2 (tagOf 8)
  (a, c4) <- recv c3
  (b, c5) <- recv c4
  close c5
  strLen a + strLen b
