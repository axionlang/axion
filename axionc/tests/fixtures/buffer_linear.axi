-- Buffer U8 %1 linear + mutação in-place (§5, estilo exemplo 03). 'encrypt'
-- consome o Buffer U8 %1 e devolve a posse (XOR in-place) — um único fio linear
-- b0→b1→b2→free, nunca clonado. sum de ((i&0xFF) ^ 90) para i em 0..1000.
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
