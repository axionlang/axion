-- A MULTI-clause function that matches constructors in its head — `fj Nothing = 0;
-- fj (Just x) = x`. Natively the clauses are tried in order, each head tested before it
-- is taken apart (an old if-chain dispatched only on Int literals and returned clause 0
-- for `fj (Just 5)`, a miscompile, so such functions used to be interpreter-only).
-- 5 on every backend.
data Maybe a = Nothing | Just a

fj :: Maybe Int -> Int
fj Nothing = 0
fj (Just x) = x

main :: Int
main = fj (Just 5)
