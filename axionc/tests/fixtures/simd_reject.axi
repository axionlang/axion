-- AX0915: natively a SIMD vector lives in vector registers, so it cannot be a tuple field.
-- (The interpreter runs this program.)
pair :: F64x4 -> (F64x4, Int)
pair v = (v, 1)

main :: Int
main = case pair (splatF64x4 1.0) of
  (w, k) -> truncate (sumF64x4 w) + k
