-- Landing fixture for the owned-`%1`-parameter drop-type move (Phase A′): the
-- `%1` param of `sum` is `List Int` — a CONCRETE instantiation of a parametric
-- type — so its drop-type key (`List$Int`) and the seed for the specialized
-- destructor `axion_drop_List$Int` are resolved at lowering and carried on the
-- function (`owned_drop_ty`), instead of re-reading the signature later.
-- 3 allocs (Cons cells) == 3 frees via the mono destructor.
data List a = Nil | Cons a (List a)

build :: Int -> List Int
build n = if n == 0 then Nil else Cons n (build (n - 1))

sum :: List Int %1 -> Int
sum xs = case xs of
  Nil -> 0
  Cons y ys -> y + sum ys

main :: Int
main = sum (build 3)
