-- Adversarial (closure-linearity arc): an ACCUMULATOR-RETURNING combiner. This is
-- the exact witness that made a naive witnessed-drop of the fold accumulator unsound
-- — `\x acc -> acc` returns the accumulator by alias and ignores the element. Under
-- the consume-ABI there is no witnessed drop: `foldr` consumes the list and moves
-- each element into the closure; the lambda returns `acc` (moved out, never dropped)
-- and discards `x`. The MUST-NOT-double-free property: `acc` is threaded to the
-- result (freed once, by main), never dropped inside the fold. Result = the base 0.
-- (The discarded elements `x` currently LEAK — a lifted USER lambda's params are not
-- yet keyed for reclamation, unlike an eta-lambda; that is the documented follow-on.
-- The point of this fixture is the corruption gate: no double-free / no UAF.)
addI :: Integer -> Integer -> Integer
addI a b = a + b

main :: IO ()
main = putStrLn (showInteger (foldr (\x acc -> acc) 0 (map fromInt (range 1 5))))
