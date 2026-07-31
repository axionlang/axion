-- AX0301: sends but never drives the endpoint to `close` — incomplete protocol.
worker :: Ep (Send Int End) %1 -> IO ()
worker chan = do
  c2 <- send chan 42
  putStrLn "feito"
