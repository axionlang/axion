-- Programa-alvo 2/5 — L0 recursão + «loop» funcional por acumulador
-- (Listagem 1.2). Sucesso da Fase 1: pattern matching, recursão, aritmética,
-- where, e a versão O(n) iterativa que o compilador deve compilar sem alocar.

fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)

-- Versão rápida: o acumulador é o «loop» funcional (Stream Fusion, sem heap).
fibFast :: Int -> Int
fibFast n = go n 0 1
  where
    go 0 a _ = a
    go k a b = go (k - 1) b (a + b)

main :: IO ()
main = putStrLn (show (fibFast 30))
