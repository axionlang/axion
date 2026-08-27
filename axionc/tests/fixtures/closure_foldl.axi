-- foldl (accumulator on the LEFT): `f z y` feeds both the accumulator and the element
-- into the closure each step. Sum 1..5 = 15.
addI :: Integer -> Integer -> Integer
addI a b = a + b
main :: IO ()
main = putStrLn (showInteger (foldl addI 0 (map fromInt (range 1 5))))
