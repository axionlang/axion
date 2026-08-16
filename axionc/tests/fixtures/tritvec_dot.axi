-- tritDot (spec §10): FUSED ternary dot product — sum_i weight(i) * acts[i],
-- decoding 5 trits/byte via the LUT in one pass (vs per-element getTritVec).
-- Borrows both the packed TritVec and the dense activation Array; both are
-- Auto-Dropped by main exactly once (no leak, no double-free).
--
-- 10 trits, weight(i) = (i mod 3)-1 = -1,0,+1,…; activations acts(i) = i.
--   w*i: 0, 0, 2, -3, 0, 5, -6, 0, 8, -9  →  sum = -3.
fillTrit :: TritVec -> Int -> Int -> TritVec
fillTrit t i n = if i == n then t else let t2 = setTritVec t i ((i `mod` 3) - 1) in fillTrit t2 (i + 1) n

fillIdx :: Array Int -> Int -> Int -> Array Int
fillIdx a i n = if i == n then a else let a2 = setArray a i i in fillIdx a2 (i + 1) n

main :: Int
main =
  let t = fillTrit (newTritVec 10 0) 0 10 in
  let a = fillIdx (newArray 10 0) 0 10 in
  tritDot t a
