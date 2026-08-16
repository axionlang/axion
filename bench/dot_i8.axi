-- `dot_i8` kernel: the SAME ternary-quantized dot product as `tritvec`, but in
-- Axion's NATURAL dense form — `Array Int` (elements are i64 = 8 bytes; Axion has
-- no native int8 array). This is the honest "what you'd actually write" baseline
-- next to the packed TritVec: it trades 40× the footprint (8 B/weight vs 0.2 B)
-- for no unpack. Weights w(i)=(i mod 3)-1, activations a(i)=(i mod 7)-3, N=50M —
-- identical result to bench/tritvec.axi (both print the same sum).
fillArr :: Array Int -> Int -> Int -> Array Int
fillArr a i n = if i == n then a else let a2 = setArray a i ((i `mod` 3) - 1) in fillArr a2 (i + 1) n

sumArr :: Array Int -> Int -> Int -> Int -> Int
sumArr a i n acc = if i == n then acc else sumArr a (i + 1) n (acc + (getArray a i) * ((i `mod` 7) - 3))

main :: Int
main = let a = newArray 50000000 0 in let a = fillArr a 0 50000000 in sumArr a 0 50000000 0
