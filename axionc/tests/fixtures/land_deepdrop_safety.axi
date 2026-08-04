-- Landing fixture for the deep-drop safety half of the deleted heuristics
-- (Phase A′): `result_may_be_heap`/`op_result_may_be_heap` now read the lowering
-- annotations. The `Node` arm transfers both heap fields out (shallow free of the
-- scrutinee — no `drop … : Tree`); the `Leaf n` arm returns a proven scalar, so
-- the scrutinee is deep-dropped (`drop … : Tree`) after the tail. `sumTree` also
-- owns its `%1` parameter (owned-param drop type from the lowering annotation).
data Tree = Leaf Int | Node Tree Tree

sumTree :: Tree %1 -> Int
sumTree t = case t of
  Leaf n -> n
  Node l r -> sumTree l + sumTree r

main :: Int
main = sumTree (Node (Leaf 1) (Leaf 2))
