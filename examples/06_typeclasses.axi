-- Typeclasses (general-purpose): per-instance dispatch + constrained polymorphism
-- `Eq a =>`. Monomorphization specializes `count` per type and LLVM inlines the
-- methods — zero-cost abstraction, à la Rust. Runs on all three executors.
-- count Red [Red,Green,Red,Blue,Red] = 3 ; count 7 [7,1,7,7] = 3 ; total = 6.
class Eq a where
  eq :: a -> a -> Bool

data Color = Red | Green | Blue

rank :: Color -> Int
rank c = case c of
  Red -> 0
  Green -> 1
  Blue -> 2

instance Eq Int where
  eq x y = x == y

instance Eq Color where
  eq a b = eq (rank a) (rank b)

count :: Eq a => a -> List a -> Int
count x xs = case xs of
  Nil -> 0
  Cons y ys -> if eq x y then 1 + count x ys else count x ys

main :: Int
main = count Red [Red, Green, Red, Blue, Red] + count 7 [7, 1, 7, 7]
