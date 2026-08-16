-- tritVecFromBuffer (§10): wrap already-packed base-243 bytes (from a Buffer, e.g.
-- loaded/mmap'd weights) into a TritVec without re-packing. Borrows the buffer
-- (freed explicitly, like sumBytes); produces an owned TritVec that `sumT` borrows,
-- so main reclaims it exactly once (no leak).
--
-- newBuffer 5 + bufIota → bytes 0,1,2,3,4 (all < 243), 25 trits. Sum of all 25
-- decoded weights = -5 + -4 + -3 + -4 + -3 = -19.
sumT :: TritVec -> Int -> Int -> Int -> Int
sumT t i n acc = if i == n then acc else sumT t (i + 1) n (acc + getTritVec t i)

main :: Int
main =
  let b = bufIota (newBuffer 5) in
  let t = tritVecFromBuffer b 25 in
  let done = free b in
  sumT t 0 25 0
