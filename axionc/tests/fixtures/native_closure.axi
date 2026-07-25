-- Backend nativo: closures (lambda-lifting + captura + chamada indirecta).
-- addN 10 = (\k -> k + 10) [captura n];  apply f x = f x [param-função].
-- main = apply (addN 10) 32 = 42.
apply :: (Int -> Int) -> Int -> Int
apply f x = f x

addN :: Int -> (Int -> Int)
addN n = \k -> k + n

main :: Int
main = apply (addN 10) 32
