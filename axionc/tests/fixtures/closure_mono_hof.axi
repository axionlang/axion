-- Follow-on #2 (closure-linearity): a MONOMORPHIC higher-order function. `reduceWith`
-- takes a combiner closure and a CONCRETE `List Integer` (no type variable), feeding each
-- element into the closure `f`. The concrete param routes it through consume-inference
-- Rule A rather than the generic Rule B, so it must ALSO treat "element moved into a
-- closure" as an escape — otherwise reduceWith borrows the list and its Integer elements
-- leak. Sum 1..5 = 15 on all three backends.
addI :: Integer -> Integer -> Integer
addI a b = a + b

reduceWith :: (Integer -> Integer -> Integer) -> Integer -> List Integer -> Integer
reduceWith f z xs = case xs of
  Nil -> z
  Cons y ys -> f y (reduceWith f z ys)

main :: IO ()
main = putStrLn (showInteger (reduceWith addI 0 (map fromInt (range 1 5))))
