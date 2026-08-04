-- Phase B, TRANSITIVE specialization: a generic-owning function (`wipe`) that
-- calls ANOTHER generic-owning function (`probe`) over the SAME type var. The
-- seed `(wipe, P)` from `main` pulls `(probe, P)` by worklist: `probe`'s call
-- is still polymorphic (`Nil :: List a`) in `wipe`'s body, so it is rewritten
-- to `probe$P` when `wipe$P` is materialized. Both specializations deep-drop
-- their owned params (`wipe$P` via `axion_drop_List$P`; `probe$P` drops the
-- `Nil` it receives, a no-op). build 3 → 6 allocs, all freed; = 1.
data P = P { a :: Int }
data List a = Nil | Cons a (List a)

build :: Int -> List P
build n = if n == 0 then Nil else Cons (P { a = n }) (build (n - 1))

probe :: List a %1 -> Int
probe xs = case xs of
  Nil -> 0
  Cons _ _ -> 2

wipe :: List a %1 -> Int
wipe xs = case xs of
  Nil -> 0
  Cons _ _ -> 1 + probe Nil

main :: Int
main = wipe (build 3)
