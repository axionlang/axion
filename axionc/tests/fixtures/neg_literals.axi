-- Negative numeric literals in prefix position (Int, Float, big Integer) and a
-- negative-INT pattern. Folded at parse time in BOTH parsers (the CST default and the
-- recursive-descent recovery parser); purely syntactic, so typing/lowering are untouched.
-- Binary `a - b`, compose `f . g`, and `f -3` (still `f - 3`) are unaffected — pinned by
-- `float_forms.axi` and the non-breaking regression tests in run.rs.
data L = N | C Int L

sumL :: L %1 -> Int
sumL xs = case xs of
  N -> 0
  C h t -> h + sumL t

classify :: Int -> Int
classify n = case n of
  -1 -> 10
  -2 -> 20
  _ -> 30

main :: IO ()
main = do
  putStrLn (showInt (0 - 7))
  putStrLn (showInt (classify (-1)))
  putStrLn (showInt (classify (-2)))
  putStrLn (showInt (classify 5))
  putStrLn (showInt (sumL (C (-1) (C (-2) (C 10 N)))))
  putStrLn (showFloat (-3.0))
  putStrLn (show (-99999999999999999999))
