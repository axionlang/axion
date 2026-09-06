-- `<=` and `>=`: defined via the `Ord` method `le`, reached through the
-- user-operator→application desugaring so the polymorphic body monomorphizes per use.
-- Exercised over Int, Float, String, and a `deriving Ord` type, plus precedence 4
-- (`1 + 2 >= 3` parses as `(1 + 2) >= 3`). Sum of the true cases = 6.
data Rank = Low | Mid | High deriving (Eq, Ord, Show)

b2i :: Bool -> Int
b2i x = if x then 1 else 0

main :: Int
main =
  b2i (3 >= 3)             -- 1
    + b2i (2 <= 5)         -- 1
    + b2i (5 <= 2)         -- 0
    + b2i (1 + 2 >= 3)     -- 1  (precedence 4)
    + b2i (3.5 <= 3.5)     -- 1  (Float)
    + b2i ("abc" <= "abd") -- 1  (String)
    + b2i (High >= Mid)    -- 1  (deriving Ord)
    + b2i (Low >= Mid)     -- 0
