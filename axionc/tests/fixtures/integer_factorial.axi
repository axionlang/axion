-- Arbitrary-precision `Integer` (§ Listing 1.4), the spec's canonical example.
-- `Int` is fixed-width and would overflow; `Integer` is exact (no wrap, at a small
-- runtime cost). Bare literals (`2`, `1`, `50`) default into `Integer` here because
-- the context (the `Integer` signature) demands it — inference makes each literal
-- Num-polymorphic and a rewrite wraps the Integer ones as `fromInt`. `factorial 50`
-- is 65 digits, computed by the hand-rolled base-1e9 bignum. Interpreter today;
-- native (C+Rust runtime bignum) is a follow-up. (Literal PATTERNS — `factorial 0
-- = 1` — still need the `if` form; that's a later slice.)
factorial :: Integer -> Integer
factorial n = if n < 2 then 1 else n * factorial (n - 1)

main :: IO ()
main = putStrLn (showInteger (factorial 50))
