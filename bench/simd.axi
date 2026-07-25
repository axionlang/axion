-- SIMD (§4/§5): soma de um Buffer U8 (redução vectorizável) repetida K vezes.
-- newBuffer+bufIota preenche byte[i]=i&0xFF; sumBytes é a primitiva vectorizável.
sumK :: Int -> Buffer -> Int
sumK 0 buf = 0
sumK k buf = sumBytes buf + sumK (k - 1) buf

main :: Int
main =
  let b0 = newBuffer 40000 in
  let b1 = bufIota b0 in
  let s = sumK 5000 b1 in
  let done = free b1 in
  s
