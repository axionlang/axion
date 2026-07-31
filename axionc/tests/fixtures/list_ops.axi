-- L0 lists (§1): literals `[..]`, cons `:`, `map`, `range`. Without declaring `List`
-- (it comes from the prelude). sumList [1,2,3] + sumList (map dbl (range 1 4)) where
-- dbl x = x + x; range 1 4 = [1,2,3,4], map dbl = [2,4,6,8], sum 20; +6 = 26.
dbl :: Int -> Int
dbl x = x + x

sumList :: List Int -> Int
sumList xs = case xs of
  Nil -> 0
  Cons y ys -> y + sumList ys

main :: Int
main = sumList (1 : 2 : 3 : Nil) + sumList (map dbl (range 1 4))
