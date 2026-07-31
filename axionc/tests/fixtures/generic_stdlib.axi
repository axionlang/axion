-- Generic prelude over typeclasses (hardening of slice 1): maxOr/minOr
-- (Ord a =>) and nub (Eq a =>), all dynamically dispatching to the prelude's
-- Eq Int / Ord Int instances. Does not regress the native path: these functions
-- call methods, so they are interp-only (the native filter excludes them; sum/++/fib
-- still compile). maxOr 0 [..]=9, minOr 100 [..]=1, length(nub [..])=4 → 14.
main :: Int
main =
  maxOr 0 [3, 1, 4, 1, 5, 9, 2, 6]
  + minOr 100 [3, 1, 4, 1, 5]
  + length (nub [1, 1, 2, 3, 3, 3, 4])
