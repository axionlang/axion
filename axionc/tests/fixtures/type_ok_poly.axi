-- Must PASS: exercises inference with 'where' (polymorphic/monomorphic go),
-- arithmetic and show/putStrLn.
sumTo :: Int -> Int
sumTo n = go n 0
  where
    go 0 acc = acc
    go k acc = go (k - 1) (acc + k)

main :: IO ()
main = putStrLn (show (sumTo 10))
