-- NESTED containers through HOFs: map dup2 builds List (List Integer); map sumL collapses
-- each inner list (consuming it); foldr sums. Exercises the poly-nested drop via closures.
addI :: Integer -> Integer -> Integer
addI a b = a + b
dup2 :: Integer -> List Integer
dup2 n = Cons n Nil
sumL :: List Integer -> Integer
sumL xs = foldr addI 0 xs
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (map sumL (map dup2 (map fromInt (range 1 5))))))
