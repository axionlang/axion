-- 200M iterations: arithmetic accumulation with `mod` (not foldable by -O2).
inner :: Int -> Int -> Int
inner acc 0 = acc
inner acc n = inner ((acc + n * n) `mod` 2147483647) (n - 1)

outer :: Int -> Int -> Int
outer acc 0 = acc
outer acc k = outer (acc + inner k 50000) (k - 1)

main :: Int
main = outer 0 4000
