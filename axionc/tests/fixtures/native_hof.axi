-- First-class functions in the NATIVE backend (closing layer 1): higher-order
-- functions from the prelude (filter/map/foldr) with lambdas, named functions as
-- values, and partial application — all via eta-expansion + closures. Compiles in
-- all three executors. 2² + 4² + 6² = 56.
sq :: Int -> Int
sq n = n * n

evenN :: Int -> Bool
evenN n = n `mod` 2 == 0

main :: Int
main = foldr (\x a -> x + a) 0 (map sq (filter evenN [1, 2, 3, 4, 5, 6]))
