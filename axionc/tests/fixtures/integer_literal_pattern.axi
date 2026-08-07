-- Num-polymorphic literal PATTERNS at Integer — the clean spec form. `fib 0`/`fib 1`
-- and the `case` arm `0 ->` match an arbitrary-precision Integer by bignum equality
-- (not the fixed-width i64 compare an Int literal pattern uses). All three backends
-- agree: fib 30 = 832040, classify 0 = 100, classify 21 = 42.
fib :: Integer -> Integer
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)

classify :: Integer -> Integer
classify n = case n of
  0 -> 100
  m -> m * 2

main :: IO ()
main = do
  putStrLn (show (fib 30))
  putStrLn (show (classify 0))
  putStrLn (show (classify 21))
