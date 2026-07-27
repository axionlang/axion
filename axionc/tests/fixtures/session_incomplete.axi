-- AX0301: envia mas nunca leva o endpoint até `close` — protocolo incompleto.
worker :: Ep (Send Int End) %1 -> IO ()
worker chan = do
  c2 <- send chan 42
  putStrLn "feito"
