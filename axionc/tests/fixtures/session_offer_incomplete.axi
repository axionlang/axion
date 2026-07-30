-- AX0304: o `case offer d` não trata o ramo `Closed` que a escolha externa
-- oferece — o cancelamento de um par em pânico ficaria por tratar em execução.
data Resp = Live (Ep End) | Closed (Ep End)
worker :: Ep (Offer (Live End) (Closed End)) %1 -> IO ()
worker d = case offer d of
  Live d2 -> close d2
