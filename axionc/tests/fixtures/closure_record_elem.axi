-- records with a HEAP (Integer) field passed through closures: map mkR builds List R,
-- map getV extracts the field; the R shells + their Integer fields must all be freed once.
addI :: Integer -> Integer -> Integer
addI a b = a + b
data R = R { rv :: Integer }
mkR :: Integer -> R
mkR n = R { rv = n }
getV :: R -> Integer
getV r = rv r
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (map getV (map mkR (map fromInt (range 1 5))))))
