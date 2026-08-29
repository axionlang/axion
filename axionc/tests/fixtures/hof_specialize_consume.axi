-- Specialization of %1-CONSUMING closures (AXION_SPECIALIZE=1): `pairUp` (whole-param embed,
-- Rule A′ %1) and `fstT` (case-extract %1) are now safe to specialize — the specialized direct
-- call MOVES the arg, matching the generic callclo's Route-C move. `map$$pairUp`/`map$$fstT`
-- must run identically to the generic path on all backends, corruption- and leak-free.
addI :: Integer -> Integer -> Integer
addI a b = a + b
pairUp :: Integer -> (Integer, Integer)
pairUp n = (n, fromInt 0)
fstT :: (Integer, Integer) -> Integer
fstT t = case t of
  (a, b) -> a
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (map fstT (map pairUp (map fromInt (range 1 5))))))
