-- A VIEW (its result shares the input's tail) whose `case` sits in one branch while the input is
-- passed on in another. The input escapes on some path, so the drop pass never frees it; the consumed
-- cell must still be freed in the `case` arms. It used to leak (clause form) or be rejected as
-- unbalanced (`if` form). 3 + 3 + 2 = 8.
data Pair = Pair String (List String)

bumpClause :: Int -> List Int -> List Int
bumpClause 0 xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons (y + 1) ys
bumpClause k xs = bumpClause (k - 1) xs

bumpIf :: Int -> List Int %1 -> List Int
bumpIf k xs = if k == 0 then (case xs of
  Nil -> Nil
  Cons y ys -> Cons (y + 1) ys) else bumpIf (k - 1) xs

rest :: Int -> Pair -> List String
rest 0 p = case p of
  Pair a b -> b
rest k p = rest (k - 1) p

main :: Int
main = length (bumpClause 2 [1, 2, 3]) + length (bumpIf 1 [4, 5, 6]) + length (rest 1 (Pair "x" ["a", "b"]))
