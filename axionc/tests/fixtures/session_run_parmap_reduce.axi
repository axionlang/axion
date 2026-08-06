-- parMap + an inline fold (§9): the reduce combinator `parMapReduce` is NOT needed
-- as a prelude function — `foldr f z (parMap w xs)` composes the fork-join with any
-- reduction directly and compiles natively. Here it takes the MAX reply: eight
-- workers compute fib 15..22 in parallel, `foldr maxOf 0` selects the largest =
-- fib 22 = 17711. Same in all three executors.
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (fib n)
  close d3

maxOf :: Int -> Int -> Int
maxOf a b = if a < b then b else a

main :: Int
main = foldr maxOf 0 (parMap worker (range 15 22))
