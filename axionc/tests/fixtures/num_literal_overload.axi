-- num_literal_overload.axi — integer LITERALS over a user numeric type, via `fromInteger` (a
-- `Num` method). A literal in expression position whose type resolves (by context) to a user
-- `Num` type is rewritten `fromInteger$T n`; `3 + half` builds `Rational 3 1` then adds.
data Rational = Rational Int Int

addR :: Rational -> Rational -> Rational
addR a b = case a of
  Rational an ad -> case b of
    Rational bn bd -> Rational (an * bd + bn * ad) (ad * bd)

instance Num Rational where
  (+) a b = addR a b
  (-) a b = addR a b
  (*) a b = addR a b
  fromInteger n = Rational n 1

showR :: Rational -> String
showR r = case r of Rational n d -> strAppend (showInt n) (strAppend "/" (showInt d))

half :: Rational
half = Rational 1 2

main :: IO ()
main = do
  putStrLn (showR (3 + half))     -- 7/2  (bare `3` → fromInteger)
  putStrLn (showR (half + 1))     -- 3/2  (bare `1` → fromInteger)
