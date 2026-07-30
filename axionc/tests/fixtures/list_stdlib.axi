-- Biblioteca de listas do prelúdio (L0, degrau 1 para propósito geral): length,
-- append, reverse, foldr, foldl, take, drop, filter, null, elem, sum — todas
-- Axion puro sobre o `List` embutido. Soma = 4+10+60+6+15+300+5+12+1+1 = 414.
b2i :: Bool -> Int
b2i b = if b then 1 else 0

evenN :: Int -> Bool
evenN n = n `mod` 2 == 0

main :: Int
main =
  length [1, 2, 3, 4]
  + sum (append [1, 2] [3, 4])
  + sum (reverse [10, 20, 30])
  + foldr (\x a -> x + a) 0 [1, 2, 3]
  + foldl (\a x -> a + x) 0 [4, 5, 6]
  + sum (take 2 [100, 200, 300])
  + sum (drop 1 [1, 2, 3])
  + sum (filter evenN [1, 2, 3, 4, 5, 6])
  + b2i (null [])
  + b2i (elem 3 [1, 2, 3])
