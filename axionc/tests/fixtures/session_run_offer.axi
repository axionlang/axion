-- Runtime da escolha (§6): o pai faz `select Live`, o worker faz `offer` e
-- despacha para o ramo Live, recebe 99 e fecha. Um valor-soma etiquetado
-- (`Live (Ep …)`) transporta o endpoint avançado. main devolve 7.
data Resp = Live (Ep (Recv Int End)) | Closed (Ep End)

worker :: Ep (Offer (Live (Recv Int End)) (Closed End)) %1 -> IO ()
worker d = case offer d of
  Live d2 -> do
    (n, d3) <- recv d2
    close d3
  Closed d2 -> close d2

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- select Live c
  c3 <- send c2 99
  close c3
  7
