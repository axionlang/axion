-- SIMD (§4/§5): sum of a U8 Buffer (vectorizable reduction) repeated K times.
-- newBuffer+bufIota fills byte[i]=i&0xFF; sumBytes is the vectorizable primitive.
sumK :: Int -> Buffer U8 -> Int
sumK 0 buf = 0
sumK k buf = sumBytes buf + sumK (k - 1) buf

main :: Int
main =
  let b0 = newBuffer 40000 in
  let b1 = bufIota b0 in
  let s = sumK 5000 b1 in
  let done = free b1 in
  s
