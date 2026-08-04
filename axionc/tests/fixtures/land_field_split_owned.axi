-- F-2 per-field ownership: `%1`-heap fields extracted from a linear record
-- are transferred out of the scrutinee; the remainder (shell + non-extracted
-- fields) is reclaimed by the remnant drop.  With AXION_HEAP_STATS=1:
-- 3 allocs (Box a, Box b, P shell) == 3 frees.

data Box = Box { v :: Int }
data P = P (Box %1) (Box %1)

sumA :: P %1 -> Int
sumA p = case p of P a b -> v a

main :: Int
main = sumA (P (Box { v = 3 }) (Box { v = 5 }))
