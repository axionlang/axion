-- A session task may bind locals with `let` and run plain statements between its channel ops.
-- `let` keeps a native helper's String across a suspension (`recv`); a statement's discarded
-- String result is freed at once, and a `let`-bound one when the task ends.
-- n = 4: tag = "n4" (len 2), echo "n4!" discarded; reply = 2 + 4 * 10 = 42.
tag :: Int -> String
tag n = strAppend "n" (showInt n)

bang :: String -> String
bang s = strAppend s "!"

worker :: Ep (Recv Int (Recv Int (Send Int End))) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  let t = tag n
  bang t
  (k, d3) <- recv d2
  let r = strLen t + n * k
  d4 <- send d3 r
  close d4

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- send c 4
  c3 <- send c2 10
  (r, c4) <- recv c3
  close c4
  r
