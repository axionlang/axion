-- combiner that ALLOCATES a fresh heap value each step: the inner `foldr consND Nil`
-- rebuilds the list (fresh spine, elements moved through), the outer fold sums it.
addI :: Integer -> Integer -> Integer
addI a b = a + b
consND :: Integer -> List Integer -> List Integer
consND x acc = Cons x acc
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (foldr consND Nil (map fromInt (range 1 5)))))
