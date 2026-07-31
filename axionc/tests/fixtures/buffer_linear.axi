-- Linear U8 %1 Buffer + in-place mutation (§5, example-03 style). 'encrypt'
-- consumes the %1 U8 Buffer and returns ownership (in-place XOR) — a single linear
-- thread b0→b1→b2→free, never cloned. sum of ((i&0xFF) ^ 90) for i in 0..1000.
encrypt :: Buffer U8 %1 -> Buffer U8 %1
encrypt buf = xorInPlace buf 90

main :: Int
main =
  let b0 = newBuffer 1000 in
  let b1 = bufIota b0 in
  let b2 = encrypt b1 in
  let s = sumBytes b2 in
  let done = free b2 in
  s
