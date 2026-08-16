-- I32Array (compact int32 array): new/setI32/getI32/lenI32/i32Sum, threaded
-- through helpers (fillI32 OWNS, sumI32 BORROWS) so it reclaims exactly once.
-- a[i] = i*1000 (needs >16 bits, fits int32); sum over 0..99 = 1000*4950 = 4950000.
fillI32 :: I32Array -> Int -> Int -> I32Array
fillI32 a i n = if i == n then a else let a2 = setI32 a i (i * 1000) in fillI32 a2 (i + 1) n
main :: Int
main = i32Sum (fillI32 (newI32Array 100 0) 0 100)
