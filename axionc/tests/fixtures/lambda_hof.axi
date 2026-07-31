-- Lambdas run in the interpreter: higher-order functions + currying via
-- chained lambdas. add (apply (\n -> n+1) 20) 21 = add 21 21 = 42.
apply :: (Int -> Int) -> Int -> Int
apply f x = f x

add :: Int -> Int -> Int
add = \x -> \y -> x + y

main :: IO ()
main = putStrLn (show (add (apply (\n -> n + 1) 20) 21))
