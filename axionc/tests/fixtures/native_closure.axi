-- Native backend: closures (lambda-lifting + capture + indirect call).
-- addN 10 = (\k -> k + 10) [captures n];  apply f x = f x [function param].
-- main = apply (addN 10) 32 = 42.
apply :: (Int -> Int) -> Int -> Int
apply f x = f x

addN :: Int -> (Int -> Int)
addN n = \k -> k + n

main :: Int
main = apply (addN 10) 32
