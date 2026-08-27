-- Interim soundness guard (AX0912): `filter` (and take/takeWhile/span/…) ALIASES its kept
-- input elements into the output list. Over a HEAP element type (Integer here) the shared
-- element would be freed by both the input's and the output's deep-drop → a native double-
-- free. Until the arrow-ownership arc makes these functions CONSUME their input, the native
-- backend REJECTS this with AX0912 (sound-by-construction: a clean error, not a silent UAF).
-- The interpreter runs it fine (Rust Drop, no aliasing hazard): sum of 3+4+5 = 12.
addI :: Integer -> Integer -> Integer
addI a b = a + b
gt2 :: Integer -> Bool
gt2 n = n > fromInt 2
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (filter gt2 (map fromInt (range 1 5)))))
