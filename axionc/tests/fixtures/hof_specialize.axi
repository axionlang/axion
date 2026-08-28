-- Higher-order specialization (AXION_SPECIALIZE=1): a HOF applied to a statically-known
-- top-level fresh-producing closure is cloned per closure (`foldr$$addI`, `map$$sq`),
-- turning `callclo` into a direct call. Result must match the generic path on all backends.
addI :: Integer -> Integer -> Integer
addI a b = a + b
sq :: Integer -> Integer
sq x = x * x
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (map sq (map fromInt (range 1 5)))))
