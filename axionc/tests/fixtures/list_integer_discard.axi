-- Discarded poly-Integer element of a `%1`-consumed list: `len` ignores each
-- bignum element and recurses on the tail. The scrutinee's non-deep `Inline` drop
-- must free each discarded `Integer` via `axion_bignum_free` — `poly_elem_drop`
-- returned Skip for Integer, silently leaking them (108 B for 3 elements).
-- 3 Cons + 3 bignum allocs, all reclaimed; len = 3.

big :: Integer
big = 1000000000000 + 1

len :: List Integer %1 -> Int
len xs = case xs of
  Nil -> 0
  Cons y ys -> 1 + len ys

main :: Int
main = len (Cons big (Cons big (Cons big Nil)))
