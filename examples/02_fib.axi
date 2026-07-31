-- Target program 2/5 — L0 recursion + functional "loop" via accumulator
-- (Listing 1.2). Phase 1 success: pattern matching, recursion, arithmetic,
-- where, and the iterative O(n) version the compiler should compile without allocating.

fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)

-- Fast version: the accumulator is the functional "loop" (Stream Fusion, no heap).
fibFast :: Int -> Int
fibFast n = go n 0 1
  where
    go 0 a _ = a
    go k a b = go (k - 1) b (a + b)

main :: IO ()
main = putStrLn (show (fibFast 30))
