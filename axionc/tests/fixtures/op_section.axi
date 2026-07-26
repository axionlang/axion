-- Secção de operador: `(+)` como valor de função de primeira classe →
-- desugar `\a b -> a + b`. Passada a uma função de ordem superior. = 7.
apply2 :: (Int -> Int -> Int) -> Int -> Int -> Int
apply2 f x y = f x y

main :: Int
main = apply2 (+) 3 4
