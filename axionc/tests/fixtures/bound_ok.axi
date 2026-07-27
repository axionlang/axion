-- Nursery bem-confinado (§9): cria um par de endpoints dentro do `bound` e
-- consome ambos lá dentro (`close`). Nada escapa → o grafo de comunicação fica
-- uma árvore (deadlock-freedom por construção). Aceite.
main :: IO ()
main = bound $ do
  (c, d) <- newChannel
  close c
  close d
