-- SIMD (docs/simd.md): a Float dot product over two 4096-element arrays, four lanes at a time
-- (F64x4 loads + fused multiply-add), repeated K times. The values are small integers, so the
-- sum is exact in any order and matches the scalar C/Rust loops bit for bit.
fill :: Array Float -> Int -> Int -> Int -> Array Float
fill a m i n = if i < n then fill (setArray a i (toFloat (i `mod` m))) m (i + 1) n else a

dotLoop :: Array Float -> Array Float -> Int -> Int -> F64x4 -> Float
dotLoop xs ys i n acc =
  if i + 4 <= n
    then dotLoop xs ys (i + 4) n (fmaF64x4 (loadF64x4 xs i) (loadF64x4 ys i) acc)
    else sumF64x4 acc

rep :: Array Float -> Array Float -> Int -> Int -> Float -> Float
rep xs ys k n acc =
  if k == 0 then acc else rep xs ys (k - 1) n (acc +. dotLoop xs ys 0 n (splatF64x4 0.0))

main :: Int
main =
  let n = 4096 in
  let xs = fill (newArray n 0.0) 7 0 n in
  let ys = fill (newArray n 0.0) 5 0 n in
  truncate (rep xs ys 20000 n 0.0)
