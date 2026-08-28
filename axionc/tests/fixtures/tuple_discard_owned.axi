-- Tuple-discard %1: a `%1` tuple whose FIRST element escapes (returned) and
-- SECOND is discarded. The discarded heap element must be reclaimed, not leaked
-- (the tuple-discard close: `case t of (a,b) -> a` frees `b`, shell-frees `t`).
-- 3 allocs (Box a, Box b, tuple shell) == 3 frees.

data Box = Box { v :: Int }

fstBox :: (Box, Box) %1 -> Box
fstBox t = case t of (a, b) -> a

main :: Int
main = v (fstBox (Box { v = 7 }, Box { v = 9 }))
