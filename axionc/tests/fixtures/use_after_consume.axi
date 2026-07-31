-- Must FAIL with AX0001: 'x' (%1) is CONSUMED twice (returned in both slots of
-- the tuple). Reading twice (x + x) would be allowed — those are borrows;
-- consuming/moving twice is what counts as contraction.
useTwice :: Int %1 -> (Int, Int)
useTwice x = (x, x)
