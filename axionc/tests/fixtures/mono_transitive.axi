-- Monomorfização TRANSITIVA (fatia 2b-β-2): uma função constrangida que chama
-- OUTRA função constrangida sobre a var genérica. `countNeq :: Eq a =>` chama
-- `neq :: Eq a =>`, que chama o método `eq`. A especialização propaga-se por
-- worklist: `countNeq$Int` → `neq$Int` → `eq$Int`. Tudo compila nativamente.
-- Corre nos três executores; conta os elementos != 2 em [1,2,2,3,2] → 2.
class Eq a where
  eq :: a -> a -> Bool

instance Eq Int where
  eq x y = x == y

neq :: Eq a => a -> a -> Bool
neq x y = if eq x y then False else True

countNeq :: Eq a => a -> List a -> Int
countNeq x xs = case xs of
  Nil -> 0
  Cons y ys -> if neq x y then 1 + countNeq x ys else countNeq x ys

main :: Int
main = countNeq 2 [1, 2, 2, 3, 2]
