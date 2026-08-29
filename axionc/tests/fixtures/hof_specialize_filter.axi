-- Specialization of a SPINE-CONSUMING partial consumer (AXION_SPECIALIZE=1): `filter` recurses
-- on its tail on BOTH branches (keep: `Cons y (filter p ys)`, discard: `filter p ys`), so the
-- spine is always consumed → the specialized `filter$$gt` is corruption-free (element-aliasing
-- gone: the direct call over a concrete element is a real %1 consume). `take`/`takeWhile` (which
-- DISCARD the tail on a branch) stay generic + AX0912. Result must match the generic path.
-- (filter's DISCARDED elements leak — the conditional-discard / poly-drop-witness gap — so this
-- validates corruption-freedom + result parity, not leak-freedom.)
addI :: Integer -> Integer -> Integer
addI a b = a + b
gt2 :: Integer -> Bool
gt2 n = n > fromInt 2
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (filter gt2 (map fromInt (range 1 5)))))
