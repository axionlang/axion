-- Contraction: 'x' (%1) is CONSUMED twice (moved into both slots) →
-- REJECTED (AX0001). Note: reading twice (x + x) would be accepted — those are
-- borrows; it is the double consume/move that is forbidden (as in GHC).
useTwice :: Int %1 -> (Int, Int)
useTwice x = (x, x)
