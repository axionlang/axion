-- USER-defined infix operators (step 2): `x `f` y` ≡ `f x y`. A named first-order
-- function used as an operator between backticks — runs in all three executors
-- (interp, --dev/Cranelift, --release/LLVM), because it lowers to a normal call.
-- clamp 100 `min` (7 `plus` 5) = min 100 12 = 12.
plus :: Int -> Int -> Int
plus a b = a + b

min :: Int -> Int -> Int
min a b = if a < b then a else b

main :: Int
main = 100 `min` (7 `plus` 5)
