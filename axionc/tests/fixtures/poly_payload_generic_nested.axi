-- Phase B, nested instantiation: the owned `%1` param `List a` is called with
-- `List (Maybe P)` — the element type itself is parametric. The specialized
-- `head1$Maybe$P` has the concrete param `List (Maybe P) %1`, whose drop-type
-- key `List$Maybe$P` resolves to the doubly-specialized destructor
-- `axion_drop_List$Maybe$P` (frees the `Some` boxes and the `P` payloads).
-- build 3 → 3 Cons + 3 Some + 3 P = 9 allocs, all freed; = 1.
data P = P { a :: Int }
data Maybe a = None | Some a
data List a = Nil | Cons a (List a)

build :: Int -> List (Maybe P)
build n = if n == 0 then Nil else Cons (Some (P { a = n })) (build (n - 1))

head1 :: List a %1 -> Int
head1 xs = case xs of
  Nil -> 0
  Cons _ _ -> 1

main :: Int
main = head1 (build 3)
