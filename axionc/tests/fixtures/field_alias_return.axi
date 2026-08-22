-- Known-bad (the last undefended memory-safety class): a function returns an INTERIOR
-- HEAP ALIAS of a parameter. `grab w = inner w` hands back a pointer into `w`'s `inner`
-- field; the value is not a fresh allocation, yet the caller treats it as owned and frees
-- it, while `w`'s own deep-drop ALSO frees `inner` — a double free (native; interp fine).
-- This is INTERPROCEDURAL (the alias crosses the grab→useW→main boundary), so the
-- per-function analysis can't see it; the drop-balance verifier's call SUMMARIES catch it
-- (`grab` returns an alias of param 0 → `useW`'s drop of that result is a DropOfAlias).
-- The default-on gate therefore REFUSES to compile this (AX0910). `--no-verify` bypasses.
data W = W { inner :: List Int, other :: List Int }

grab :: W -> List Int
grab w = inner w

useW :: W -> Int
useW w = length (grab w)

main :: Int
main = useW (W { inner = Cons 1 (Cons 2 Nil), other = Cons 9 Nil })
