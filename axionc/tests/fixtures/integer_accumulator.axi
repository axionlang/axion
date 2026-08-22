-- Path-sensitive reclamation of a conditionally-escaping OWNED Integer param. `acc` is
-- RETURNED in the base arm (escapes) but in the recursive arm it is used (`acc * 2`) and
-- then dead — the branch-insensitive escape analysis excludes it from the normal drop set
-- on ALL paths, so it used to leak once per call. `reclaim_cond_escape` now drops it on
-- the path where it dies (after its last use) while leaving the escaping arm alone.
-- Leak-free (sanitize.sh). countDown 8 (1) = 1 * 2^8 = 256 == 256 → 1.
countDown :: Int -> Integer -> Integer
countDown k acc =
  if k < 1
    then acc
    else countDown (k - 1) (acc * fromInt 2)

main :: Int
main = case countDown 8 (fromInt 1) == fromInt 256 of
  True -> 1
  False -> 0
