-- Listagem 1.3 da spec (L0): FizzBuzz — guardas, `mod`, ranges `[1..N]`,
-- composição `.`, `mapM_`. `mapM_ (putStrLn . fizzbuzz) [1..15]`.
fizzbuzz :: Int -> String
fizzbuzz n
  | n `mod` 15 == 0 = "FizzBuzz"
  | n `mod` 3 == 0  = "Fizz"
  | n `mod` 5 == 0  = "Buzz"
  | otherwise       = show n

main :: IO ()
main = mapM_ (putStrLn . fizzbuzz) [1 .. 15]
