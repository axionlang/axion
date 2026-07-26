-- Reclamação de argumento emprestado (Auto-Drop §2): `dist` só lê os campos do
-- registo (empréstimo puro), pelo que `main` — que o aloca — pode libertá-lo
-- após a chamada em vez de o dar por perdido. Com AXION_HEAP_STATS=1 conta-se
-- 1 alocação e 1 libertação. dist(P 3 4) = 3 + 4 = 7.
data P = P { px :: Int, py :: Int }

dist :: P -> Int
dist p = px p + py p

main :: Int
main = dist (P { px = 3, py = 4 })
