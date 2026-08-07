-- Arbitrary-precision `Integer` (§ Listing 1.4): `factorial 50` overflows a
-- fixed-width `Int` but is exact with `Integer` (no wrap, at a small runtime cost).
-- The result — 65 digits — is computed by the hand-rolled base-1e9 bignum (mul,
-- sub, ==, show). `fromInt`/`showInteger` are the Int↔Integer conversions; a later
-- slice makes bare literals default into `Integer` by type (so `n - 1` works).
-- Interpreter today; native (C+Rust runtime bignum) is a follow-up.
fac :: Integer -> Integer
fac n = if n == fromInt 0 then fromInt 1 else n * fac (n - fromInt 1)

main :: IO ()
main = putStrLn (showInteger (fac (fromInt 50)))
