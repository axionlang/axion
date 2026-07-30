-- AX0305: a closure passada a `spawn` captura o endpoint `a` do exterior. Dois
-- filhos podiam então partilhar canais e formar um ciclo → deadlock. Um filho só
-- pode comunicar com o pai pelo seu endpoint-parâmetro (topologia em árvore, §9).
main :: Int
main = bound $ do
  (a, b) <- newChannel
  c <- spawn (\d -> send a 1)
  close b
  close c
  0
