-- Buffer U8 linear (§4/§5): newBuffer aloca, bufIota preenche in-place
-- (byte[i]=i&0xFF), sumBytes soma (empresta), free consome. Para 100 bytes,
-- byte[i]=i → sum(0..99)=4950. O fio linear (%1) é único: b→b1→free.
main :: Int
main =
  let b = newBuffer 100 in
  let b1 = bufIota b in
  let s = sumBytes b1 in
  let done = free b1 in
  s
