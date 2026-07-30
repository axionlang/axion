-- Operadores infixos de UTILIZADOR (degrau 2): `x `f` y` ≡ `f x y`. Uma função
-- nomeada de 1ª ordem usada como operador entre backticks — corre nos três
-- executores (interp, --dev/Cranelift, --release/LLVM), porque baixa a uma
-- chamada normal. clamp 100 `min` (7 `plus` 5) = min 100 12 = 12.
plus :: Int -> Int -> Int
plus a b = a + b

min :: Int -> Int -> Int
min a b = if a < b then a else b

main :: Int
main = 100 `min` (7 `plus` 5)
