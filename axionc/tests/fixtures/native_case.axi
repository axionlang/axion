-- Native backend: 'case' (chain of if) + tuples on the heap.
-- swapSum 10 = (10,11) → b-a = 1;  classify 1 = 200.  main = 200.
swapSum :: Int -> Int
swapSum n = case (n, n + 1) of
  (a, b) -> b - a

classify :: Int -> Int
classify k = case k of
  0 -> 100
  1 -> 200
  x -> x

main :: Int
main = classify (swapSum 10)
