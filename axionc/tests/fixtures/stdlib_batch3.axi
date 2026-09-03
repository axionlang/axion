-- Prelude breadth batch 3: comparator/predicate HOFs — nubBy, maximumByOr, minimumByOr,
-- scanl1, count. nubBy exercises the closure-capture borrow fix (its inner filter lambda
-- captures both the predicate and the pivot). All leak-free over scalars (verifier + ASan +
-- LSan clean on every backend).
eqi :: Int -> Int -> Bool
eqi a b = a == b

gti :: Int -> Int -> Bool
gti a b = a > b

lti :: Int -> Int -> Bool
lti a b = a < b

add :: Int -> Int -> Int
add a b = a + b

big :: Int -> Bool
big n = n > 3

main :: IO ()
main = putStrLn (show
  ( length (nubBy eqi (Cons 1 (Cons 1 (Cons 2 (Cons 1 Nil)))))
  + maximumByOr gti 0 (Cons 3 (Cons 9 (Cons 5 Nil)))
  + minimumByOr lti 100 (Cons 3 (Cons 9 (Cons 5 Nil)))
  + sum (scanl1 add (Cons 1 (Cons 2 (Cons 3 Nil))))
  + count big (Cons 1 (Cons 5 (Cons 9 (Cons 2 Nil)))) ))
