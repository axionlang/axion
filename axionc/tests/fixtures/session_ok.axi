-- Sessão bem-tipada (§6): o endpoint envia um Int e fecha, seguindo o protocolo
-- `Send Int End`. O `check_sessions` aceita; a linearidade do endpoint (%1) e a
-- fidelidade de protocolo estão ambas satisfeitas.
worker :: Ep (Send Int End) %1 -> IO ()
worker chan = do
  c2 <- send chan 42
  close c2
