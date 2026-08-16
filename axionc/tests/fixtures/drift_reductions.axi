-- Drift guard: exercises the fused int reductions over N crossing the i8DotI8
-- int32-block boundary (N=40000 > 32768), with edge byte values injected, so any
-- C-vs-Rust divergence in blocking/overflow/decode shows in the checksum. Output
-- value is unimportant — the test asserts --dev == --release.
seed :: I8Array -> Int -> Int -> I8Array
seed a i n = if i == n then a else let a2 = setI8 a i (((i * 37) `mod` 255) - 127) in seed a2 (i + 1) n
main :: Int
main =
  let w = seed (i8Iota 40000) 0 40000 in    -- int8 weights incl. ±127 edges
  let v = i8Iota 40000 in                     -- second int8 operand
  let acts = arrayIota 40000 in               -- i64 activations
  let d1 = i8DotI8 w v in                     -- blocked int32 path, crosses BLK
  let d2 = i8Dot w acts in                    -- int8 × i64
  let s1 = i8Sum w in
  let ar = arrayIota 40000 in
  let d3 = arrayDot ar acts in
  let s2 = arraySum ar in
  let iv = i32Iota 40000 in
  let d4 = i32Dot iv acts in
  let s3 = i32Sum iv in
  d1 + d2 + s1 + d3 + s2 + d4 + s3
