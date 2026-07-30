-- Runtime do cancelamento (§7, T5): o pai faz `cancel c`, que envia `Closed` ao
-- par; o worker faz `offer` e recebe `Closed`, tomando o ramo de cancelamento.
-- O `Closed` é um ramo normal do protocolo, não uma excepção. main devolve 5.
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
