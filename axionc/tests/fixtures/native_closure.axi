-- Native backend: closures (lambda-lifting + capture + indirect call).
-- addN n = (\k -> k + n) [captures n]. The closure is bound to a LOCAL (`g`) and passed to
-- `apply` through it — higher-order specialization resolves only closure NAMES, not locals,
-- so `apply g` stays a genuine `callclo` (were the closure written inline, `apply (addN n)`,
-- it would specialize away). `addN n` captures `n` in the closure's env. mk 10 = apply (addN
-- 10) 32 = (10 + 32) = 42.
apply :: (Int -> Int) -> Int -> Int
apply f x = f x

addN :: Int -> (Int -> Int)
addN n = \k -> k + n

mk :: Int -> Int
mk n = let g = addN n in apply g 32

main :: Int
main = mk 10
