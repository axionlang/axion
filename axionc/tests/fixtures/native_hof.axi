-- First-class functions no NATIVO (fecho da camada 1): funções de ordem superior
-- do prelúdio (filter/map/foldr) com lambdas, funções nomeadas como valor, e
-- aplicação parcial — tudo via eta-expansão + closures. Compila nos três
-- executores. 2² + 4² + 6² = 56.
sq :: Int -> Int
sq n = n * n

evenN :: Int -> Bool
evenN n = n `mod` 2 == 0

main :: Int
main = foldr (\x a -> x + a) 0 (map sq (filter evenN [1, 2, 3, 4, 5, 6]))
