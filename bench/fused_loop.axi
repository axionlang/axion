-- Stream-fusion demonstration: `sum (range 1 200000000)` with --fuse
-- compiles to a tight arithmetic loop (zero allocations, zero Cons cells).
-- Equivalent to C's `for (i=1; i<=200M; i++) s += i`.
-- Expected: 20000000100000000  (200M * (200M+1) / 2)
main :: Int
main = sum (range 1 200000000)
