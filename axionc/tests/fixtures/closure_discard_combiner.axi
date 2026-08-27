-- DOUBLE-DISCARD combiner: const0 ignores BOTH args and returns a fresh 0 — every element
-- and every intermediate accumulator must be freed. foldr const0 0 [1..5] = 0.
const0 :: Integer -> Integer -> Integer
const0 a b = fromInt 0
main :: IO ()
main = putStrLn (showInteger (foldr const0 (fromInt 0) (map fromInt (range 1 5))))
