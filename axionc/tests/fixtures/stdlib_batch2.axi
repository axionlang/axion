-- Prelude breadth batch 2: scanl, zipWith3, findIndices/elemIndices, comparing, on.
-- All leak-free over scalar element types (verifier + ASan + LSan clean on every backend).
add :: Int -> Int -> Int
add a b = a + b

add3 :: Int -> Int -> Int -> Int
add3 a b c = a + b + c

dbl :: Int -> Int
dbl n = n + n

isBig :: Int -> Bool
isBig n = n > 3

main :: IO ()
main = putStrLn (show
  ( sum (scanl add 0 (Cons 1 (Cons 2 (Cons 3 Nil))))
  + sum (zipWith3 add3 (Cons 1 (Cons 2 Nil)) (Cons 10 (Cons 20 Nil)) (Cons 100 (Cons 200 Nil)))
  + sum (findIndices isBig (Cons 5 (Cons 1 (Cons 9 (Cons 2 Nil)))))
  + sum (elemIndices 3 (Cons 3 (Cons 1 (Cons 3 Nil))))
  + (if comparing dbl 5 2 then 0 else 7)
  + on add dbl 3 4 ))
