-- Multi-var owning params: `Tree a b %1` carries TWO type variables,
-- both specialized to `Int` at the call site.  The template
-- `sumTree :: Tree a b %1 -> Int` is monomorphized to `sumTree$Int$Int`.
-- 3 allocs (2 Leaf + 1 Node) == 3 frees.

data Tree a b = Leaf a b | Node (Tree a b) (Tree a b)

sumTree :: Tree a b %1 -> Int
sumTree t = case t of
  Leaf x y -> 0
  Node l r -> sumTree l

main :: Int
main = sumTree (Node (Leaf 1 2) (Leaf 3 4))
