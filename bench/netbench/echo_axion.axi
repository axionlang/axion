-- Concurrent keep-alive TCP echo server — Axión (M:N session tasks, one spawned handler per
-- connection). Identical protocol to the Rust/C/Haskell servers. See examples/echoserver.axi.
handler :: Sock %1 -> IO ()
handler s = do
  msg <- netRecv s
  if strLen msg == 0
    then netClose s
    else do
      _ <- netSend s msg
      handler s

serve :: Listener %1 -> IO ()
serve l = do
  s <- netAccept l
  _ <- spawn (handler s)
  serve l

main :: Int
main = bound $ do
  l <- netListen 47004
  _ <- spawn (serve l)
  0
