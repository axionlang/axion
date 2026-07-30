-- Prelúdio, degrau 3: ++ (concatenação), concat, zipWith, zip. Tudo Axión puro
-- sobre o `List` embutido. sum ([1,2]++[3,4]++[10]) = 20; sum(concat[[1],[2,3]])
-- = 6; sum(zipWith (*) [1,2,3] [10,20,30,40]) = 140; sum(map snd (zip[1,2][5,6]))
-- = 11. Total = 20 + 6 + 140 + 11 = 177.
snd :: (Int, Int) -> Int
snd p = case p of
  (a, b) -> b

main :: Int
main =
  sum ([1, 2] ++ [3, 4] ++ [10])
  + sum (concat [[1], [2, 3]])
  + sum (zipWith (\a b -> a * b) [1, 2, 3] [10, 20, 30, 40])
  + sum (map snd (zip [1, 2] [5, 6]))
