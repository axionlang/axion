-- Operator section: `(+)` as a first-class function value →
-- desugars to `\a b -> a + b`. Passed to a higher-order function. = 7.
apply2 :: (Int -> Int -> Int) -> Int -> Int -> Int
apply2 f x y = f x y

main :: Int
main = apply2 (+) 3 4
