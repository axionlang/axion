-- Auto-Drop at runtime: each call to 'step' allocates a local tuple and frees
-- it at the death point (after destructuring). 'sumTo 300' calls 'step' 300
-- times → 300 allocs == 300 frees, constant memory (no GC).
-- Result: sum of step(n)=2n for n=1..300 = 90300.
step :: Int -> Int
step n = case (n, n) of
  (a, b) -> a + b

sumTo :: Int -> Int
sumTo 0 = 0
sumTo n = step n + sumTo (n - 1)

main :: Int
main = sumTo 300
