-- I8Array (Phase B): new / setI8 (in-place, consumes+returns) / getI8 (signed
-- read) / lenI8, threaded through helpers like Array (fillI8 OWNS, sumI8 BORROWS)
-- so the fixpoint borrow analysis reclaims the array exactly once — no leak, no
-- double-free. Stores i-3 as a signed byte at each index; sum over 0..99 of
-- (i-3) = (0+..+99) - 3*100 = 4950 - 300 = 4650.
fillI8 :: I8Array -> Int -> Int -> I8Array
fillI8 a i n = if i == n then a else let a2 = setI8 a i (i - 3) in fillI8 a2 (i + 1) n

sumI8 :: I8Array -> Int -> Int -> Int -> Int
sumI8 a i n acc = if i == n then acc else sumI8 a (i + 1) n (acc + getI8 a i)

main :: Int
main = let a = fillI8 (newI8Array 100 0) 0 100 in sumI8 a 0 100 0
