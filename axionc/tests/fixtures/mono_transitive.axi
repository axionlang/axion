-- TRANSITIVE monomorphization (slice 2b-β-2): a constrained function that calls
-- ANOTHER constrained function over the generic var. `countNeq :: Eq a =>` calls
-- `neq :: Eq a =>`, which calls the method `eq`. The specialization propagates via
-- a worklist: `countNeq$Int` → `neq$Int` → `eq$Int`. Everything compiles natively.
-- Runs in all three executors; counts the elements != 2 in [1,2,2,3,2] → 2.
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
