-- Auto-Drop no runtime: cada chamada de 'step' aloca um tuplo local e
-- liberta-o no ponto de morte (após a destructuração). 'sumTo 300' chama
-- 'step' 300 vezes → 300 allocs == 300 frees, memória constante (sem GC).
-- Resultado: soma de step(n)=2n para n=1..300 = 90300.
step :: Int -> Int
step n = case (n, n) of
  (a, b) -> a + b

sumTo :: Int -> Int
sumTo 0 = 0
sumTo n = step n + sumTo (n - 1)

main :: Int
main = sumTo 300
