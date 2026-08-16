-- `dot_i8` kernel: FAIR dense int8 dot product — both operands are compact
-- I8Array (1 byte/elem, ~50 MB each), matching what C/Rust would write. i8DotI8
-- streams two int8 arrays and MACs in one fused pass; both Auto-Dropped once.
-- weight(i)=(i mod 3)-1 for both → sum of squares = count of nonzero = 33333333.
main :: Int
main = i8DotI8 (i8Iota 50000000) (i8Iota 50000000)
