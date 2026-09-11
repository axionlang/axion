-- The nested-tuple poly-payload residual (found by the differential fuzzer). An element-
-- EXTRACTING list consumer (`take`/`drop`/`head`/`last`/`uncons`) over a TUPLE element type
-- (`List (Integer, Integer)`) extracts a tuple payload the monomorphizer cannot lower natively
-- — before the gate covered it, native compilation silently dropped `main`. AX0912 now REJECTS
-- it fail-closed (over a non-tuple heap element — String / Integer / a nested list — the same
-- functions compile + run; and `map`/`reverse` over tuples are fine, they don't extract). The
-- interpreter reclaims via Rust Drop and runs it → 3.
pairUp :: Integer -> (Integer, Integer)
pairUp n = (n, fromInt 0)
fstT :: (Integer, Integer) -> Integer
fstT t = case t of
  (a, b) -> a
addI :: Integer -> Integer -> Integer
addI a b = a + b
main :: IO ()
main = putStrLn (showInteger (foldl addI 0 (map fstT (take 2 (map pairUp (map fromInt (range 1 4)))))))
