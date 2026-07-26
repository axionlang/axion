-- foldBytes executável: dobra a closure sobre os bytes (chamada indirecta por
-- byte no runtime). checksum com a secção `(+)` = soma dos bytes = 4950.
checksum :: Buffer U8 -> Int
checksum buf = foldBytes (+) 0 buf

main :: Int
main =
  let b0 = newBuffer 100 in
  let b1 = bufIota b0 in
  let s = checksum b1 in
  let done = free b1 in
  s
