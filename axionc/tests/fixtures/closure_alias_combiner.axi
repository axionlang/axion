-- ALIAS-RETURNING combiner over heap: maxI returns ONE of its two Integer args (by alias)
-- and must drop the OTHER. Exercises conditional single-arg reclamation inside the fold.
-- max of 1..5 = 5.
maxI :: Integer -> Integer -> Integer
maxI a b = if a > b then a else b
main :: IO ()
main = putStrLn (showInteger (foldr maxI (fromInt 0) (map fromInt (range 1 5))))
