-- rational.axi — the payoff of the completed numeric story: a user `Rational` that is a
-- first-class number. `Num`/`Division`/`Eq`/`Ord` are ordinary classes, so `+ - * /`, `== < <=`,
-- and integer LITERALS (`3 + half`, via `fromInteger`) all work with the built-in syntax. Values
-- are kept in lowest terms by `gcd`; fields are `Int` (scalar → no heap).
data Rational = Rational Int Int

num :: Rational -> Int
num r = case r of Rational n d -> n
den :: Rational -> Int
den r = case r of Rational n d -> d

gcdI :: Int -> Int -> Int
gcdI a b = if b == 0 then a else gcdI b (a `mod` b)

absI :: Int -> Int
absI x = if x < 0 then 0 - x else x

-- reduce to lowest terms, denominator kept positive
mkR :: Int -> Int -> Rational
mkR n d =
  let g = gcdI (absI n) (absI d) in
  let g2 = if g == 0 then 1 else g in
  let s = if d < 0 then 0 - 1 else 1 in
  Rational ((s * n) `div` g2) ((s * d) `div` g2)

addR :: Rational -> Rational -> Rational
addR a b = mkR (num a * den b + num b * den a) (den a * den b)
subR :: Rational -> Rational -> Rational
subR a b = mkR (num a * den b - num b * den a) (den a * den b)
mulR :: Rational -> Rational -> Rational
mulR a b = mkR (num a * num b) (den a * den b)
divR :: Rational -> Rational -> Rational
divR a b = mkR (num a * den b) (den a * num b)

instance Num Rational where
  (+) a b = addR a b
  (-) a b = subR a b
  (*) a b = mulR a b
  fromInteger n = Rational n 1

instance Division Rational where
  (/) a b = divR a b

instance Eq Rational where
  eq a b = num a * den b == num b * den a

instance Ord Rational where
  le a b = num a * den b <= num b * den a

showR :: Rational -> String
showR r = strAppend (showInt (num r)) (strAppend "/" (showInt (den r)))

half :: Rational
half = Rational 1 2
third :: Rational
third = Rational 1 3

main :: IO ()
main = do
  putStrLn (showR (3 + half))            -- 7/2   (literal `3` → fromInteger)
  putStrLn (showR (half + third))        -- 5/6
  putStrLn (showR (half * third))        -- 1/6
  putStrLn (showR (half / third))        -- 3/2
  putStrLn (showR (half - third))        -- 1/6
  putStrLn (if half == Rational 2 4 then "eq" else "ne")   -- eq  (reduced)
  putStrLn (if third < half then "lt" else "ge")           -- lt
  putStrLn (if half <= half then "le" else "gt")           -- le
