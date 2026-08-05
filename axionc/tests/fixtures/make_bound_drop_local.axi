-- Phase 4 — Make-bound local drop: `lst` is a Cons chain built via `let`, so the
-- Cons cells never escape via `return` (unlike `make_bound_drop.axi` where `build`
-- returns the list). The lowered `MakeCon` ops carry the mono-key `List$P` from
-- inference, so Auto-Drop routes to `axion_drop_List$P` which reclaims the
-- `P` payloads. After a `case`-extraction of the first `P`, the remainder
-- `List$P` is dropped, and the extracted `P` is freed at the arm's end.
-- 2 Cons + 2 P = 4 allocs, all freed. Result: x y = 5.

data List a = Nil | Cons a (List a)
data P = P { x :: Int }

main :: Int
main = let lst = Cons (P { x = 5 }) (Cons (P { x = 6 }) Nil) in
       case lst of
         Cons y _ -> x y
         Nil -> 0
