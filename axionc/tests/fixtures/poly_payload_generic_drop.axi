-- Phase B (generic-owning corner, memory-model-options §7.3): a GENERIC
-- function that OWNS its `%1` parameter — `head1 :: List a %1 -> Int` — where
-- the parameter type still carries the type variable `a`. A generic body
-- cannot free the payloads itself (at runtime an i64 is indistinguishable
-- pointer-vs-Int), and the drop-type key of `List a` is unresolvable at
-- lowering (`mono_key` fails on the var) — so the param used to be flat-freed:
-- the spine was reclaimed but the `P` payloads leaked. Phase B MONOMORPHIZES
-- the owning generic per concrete call site (`head1$P`), whose body deep-drops
-- the `List P` parameter via the specialized destructor `axion_drop_List$P`.
-- build 3 → 3 Cons cells + 3 P records = 6 allocs, all freed; = 1.
data P = P { a :: Int }
data List a = Nil | Cons a (List a)

build :: Int -> List P
build n = if n == 0 then Nil else Cons (P { a = n }) (build (n - 1))

head1 :: List a %1 -> Int
head1 xs = case xs of
  Nil -> 0
  Cons _ _ -> 1

main :: Int
main = head1 (build 3)
