-- SIMD (§4): soma de um Buffer (redução vectorizável) repetida K vezes.
-- iota N cria [0..N); sumBuffer é a primitiva vectorizável (laço no runtime).
sumK :: Int -> Buffer -> Int
sumK 0 buf = 0
sumK k buf = sumBuffer buf + sumK (k - 1) buf

main :: Int
main =
  let buf = iota 40000 in
  let s = sumK 5000 buf in
  let done = freeBuffer buf in
  s
