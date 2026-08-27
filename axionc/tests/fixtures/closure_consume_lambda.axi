-- Adversarial (closure-linearity arc): a CONSUMING lambda. `\x -> Box x` moves its
-- Integer argument INTO the result (the element escapes the lambda into the Box), so
-- the lifted lambda must NOT drop it — dropping it would double-free against the Box
-- that now owns it. `map (\x -> Box x)` consumes the source list; the new list of
-- Boxes owns the Integers; `map unbox` + `foldr addI` then consume the boxes. Every
-- Integer + Box + spine cell freed exactly once, no use-after-free. Sum 1..5 = 15.
data Box = Box Integer

addI :: Integer -> Integer -> Integer
addI a b = a + b

unbox :: Box -> Integer
unbox b = case b of
  Box i -> i

main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (map unbox (map (\x -> Box x) (map fromInt (range 1 5))))))
