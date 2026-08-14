-- A MULTI-clause function that matches constructors in its head — `fj Nothing = 0;
-- fj (Just x) = x` — is the documented "write the match with `case`" limitation.
-- The `if`-chain desugar dispatches only on Int literals, NOT on constructor tags,
-- so natively it selected clause 0 UNCONDITIONALLY: `fj (Just 5)` silently returned
-- 0 (a miscompile), while the interpreter correctly returns 5. Such a function is
-- now EXCLUDED from native (interpreter only) — `--backend` fails loudly rather than
-- returning the wrong value.
data Maybe a = Nothing | Just a

fj :: Maybe Int -> Int
fj Nothing = 0
fj (Just x) = x

main :: Int
main = fj (Just 5)
