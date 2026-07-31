-- Linear U8 Buffer (§4/§5): newBuffer allocates, bufIota fills in-place
-- (byte[i]=i&0xFF), sumBytes sums (borrows), free consumes. For 100 bytes,
-- byte[i]=i → sum(0..99)=4950. The linear thread (%1) is unique: b→b1→free.
main :: Int
main =
  let b = newBuffer 100 in
  let b1 = bufIota b in
  let s = sumBytes b1 in
  let done = free b1 in
  s
