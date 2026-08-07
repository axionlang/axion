-- Integration stress (§Listing 1.4): `Integer` as a first-class citizen.
-- `map fromInt` passes the `fromInt` builtin as a VALUE (eta-expanded to a closure
-- that must not capture it as a free variable); `map sq`/`foldr addI` process a
-- `List Integer`; and `show` dispatches via the `Show Integer` instance (not the
-- raw `showInteger`). Sum of squares 1..10 = 385. All three executors agree.
sq :: Integer -> Integer
sq x = x * x

addI :: Integer -> Integer -> Integer
addI a b = a + b

main :: IO ()
main = putStrLn (show (foldr addI 0 (map sq (map fromInt (range 1 10)))))
