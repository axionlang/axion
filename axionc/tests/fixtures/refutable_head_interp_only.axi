-- A single-clause function whose head is a REFUTABLE pattern — a `Con` of a
-- MULTI-constructor type (`Just x`, with `Nothing` also possible) — is a PARTIAL
-- function. There is no exhaustiveness check on clause heads (AX0202 covers only
-- `case`), so it must NOT be destructured natively: matching `Nothing` as `Just`
-- and loading its field is memory-unsafe. It is excluded from native (interpreter
-- only), which reports a no-match at runtime. Called here with a matching `Just`,
-- so the interpreter returns 5; `--backend` must fail loudly, never miscompile.
data Maybe a = Nothing | Just a

fromJust :: Maybe Int -> Int
fromJust (Just x) = x

main :: Int
main = fromJust (Just 5)
