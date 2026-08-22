-- Integer (bignum) reclamation (§Auto-Drop): a boxed `Integer` is now freed by the
-- tagged `axion_bignum_free` (the BigNum struct + its limbs), so transient Integers are
-- not leaked. Exercises the reclaimed positions: `fromInt` producers, arithmetic
-- intermediates (`*`), a function RESULT of type Integer (`sq`/`cube`), a BORROWED
-- Integer parameter (`x` read twice), and a comparison (`==`, borrows both). No `IO`, so
-- `main :: Int` and LSan can prove 0 leaks.
--   cube 4 = 4 * (4 * 4) = 64  →  main = 1
sq :: Integer -> Integer
sq x = x * x

cube :: Integer -> Integer
cube x = x * sq x

main :: Int
main = case cube (fromInt 4) == fromInt 64 of
  True -> 1
  False -> 0
