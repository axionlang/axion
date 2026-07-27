-- AX0300: o protocolo é `Send Int End`, mas o corpo faz `recv` — a operação não
-- segue o tipo de sessão do endpoint.
worker :: Ep (Send Int End) %1 -> IO ()
worker chan = do
  (x, c2) <- recv chan
  close c2
