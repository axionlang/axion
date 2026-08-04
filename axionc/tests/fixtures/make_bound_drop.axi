-- Phase 4 — Make-bound locals: `build` constructs a `List P` via `Cons`
-- and `Nil` (no `%1` param involved).  The lowered `MakeCon` nodes carry
-- the mono-key `"List$P"` (from inference) instead of just `"List"`, so
-- Auto-Drop routes to `axion_drop_List$P` which reclaims the `P` payloads.
-- 3 Cons + 3 P = 6 allocs, all freed.

data List a = Nil | Cons a (List a)
data P = P { x :: Int }

build :: Int -> List P
build n = if n == 0 then Nil else Cons (P { x = n }) (build (n - 1))

main :: Int
main = case build 3 of
  Cons y _ -> x y
  Nil -> 0
