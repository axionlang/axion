-- F-3 per-field ownership with mixed transfers: `a :: Box %1` is extracted
-- (transferred), `b :: Box` (many) stays with the record — the remainder
-- reclaims `b` + the shell via the skip-variant destructor.
-- 3 allocs (Box a, Box b, P shell) == 3 frees.

data Box = Box { v :: Int }
data P = P (Box %1) (Box)

sumA :: P %1 -> Int
sumA p = case p of P a b -> v a

main :: Int
main = sumA (P (Box { v = 3 }) (Box { v = 5 }))
