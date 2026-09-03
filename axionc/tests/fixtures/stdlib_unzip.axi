-- `unzip`/`zip3`: tuple list HOFs, leak-free now that container destructors reclaim tuple cells
-- (the tuple-shell reclamation fix). unzip [(1,2),(3,4)] = ([1,3],[2,4]) → 4+6 = 10; zip3 of
-- {1,2}/{10,20}/{100,200} summed = 333. Total = 343 on every backend (verifier + ASan + LSan).
sumBoth :: (List Int, List Int) -> Int
sumBoth ab = case ab of
  (a, b) -> sum a + sum b

add3 :: Int -> Int -> Int -> Int
add3 a b c = a + b + c

sum3 :: List (Int, Int, Int) -> Int
sum3 ts = case ts of
  Nil -> 0
  Cons t rest -> case t of
    (a, b, c) -> a + b + c + sum3 rest

main :: IO ()
main = putStrLn (show
  ( sumBoth (unzip (Cons (1, 2) (Cons (3, 4) Nil)))
  + sum3 (zip3 (Cons 1 (Cons 2 Nil)) (Cons 10 (Cons 20 Nil)) (Cons 100 (Cons 200 Nil))) ))
