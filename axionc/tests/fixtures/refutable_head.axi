-- A single-clause function whose head is a REFUTABLE pattern — a `Con` of a
-- MULTI-constructor type (`Just x`, with `Nothing` also possible) — is a PARTIAL
-- function. Natively its head is TESTED before it is taken apart (destructuring
-- `Nothing` as `Just` would be memory-unsafe), and a call it does not match fails at
-- run time as in the interpreter. Called here with a matching `Just`: 5 everywhere.
data Maybe a = Nothing | Just a

fromJust :: Maybe Int -> Int
fromJust (Just x) = x

main :: Int
main = fromJust (Just 5)
