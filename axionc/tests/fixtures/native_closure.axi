-- Native backend: closures (lambda-lifting + capture + indirect call).
-- addN n = (\k -> k + n) [captures n];  apply f x = f x [function param].
-- The addend is threaded through `mk`'s parameter so the partial application
-- `addN n` captures a VARIABLE (not a constant) — the closure carries `n` in its
-- env. (`absorb_lambda_caf` turns `addN` into a direct two-parameter function, so
-- the capturing closure is now formed by eta-expansion at the partial application
-- `addN n`, which is the same first-class-closure path.) mk 10 = apply (addN 10) 32 = 42.
apply :: (Int -> Int) -> Int -> Int
apply f x = f x

addN :: Int -> (Int -> Int)
addN n = \k -> k + n

mk :: Int -> Int
mk n = apply (addN n) 32

main :: Int
main = mk 10
