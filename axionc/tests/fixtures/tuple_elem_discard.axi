-- notion-2 reclamation: a `%1` list of TUPLES, mapping to the first element and
-- DISCARDING the second. The tuple `t` flows into an inner `case t of (a,b)` that
-- is reclaimed by nothing until the element is made owned — the inner case then
-- frees the discarded `Box b` and shell-frees the tuple cell (`mapFst`'s leak).
-- Every alloc (2 tuples, 4 Box, 2 outer Cons) is reclaimed: allocs == frees.

data Box = Box { v :: Int }

mapFst :: List (Box, Box) %1 -> List Box
mapFst xs = case xs of
  Nil -> Nil
  Cons t ts -> case t of (a, b) -> Cons a (mapFst ts)

countV :: List Box %1 -> Int
countV xs = case xs of
  Nil -> 0
  Cons h t -> 1 + countV t

main :: Int
main = countV (mapFst (Cons (Box { v = 3 }, Box { v = 9 }) (Cons (Box { v = 4 }, Box { v = 9 }) Nil)))
