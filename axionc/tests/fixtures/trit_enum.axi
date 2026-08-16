-- Trit (spec §10.A): the balanced-ternary three-state enum, an ordinary N=3
-- sum type from the prelude.  A value-selecting `case` lowers branchless like
-- any small enum; here we sum the ternary weights (-1 + 0 + 1 = 0) and also
-- exercise the derived `Show`.
tritVal :: Trit -> Int
tritVal t = case t of
  TMinus -> 0 - 1
  TZero -> 0
  TPlus -> 1

main :: IO ()
main = putStrLn (show (tritVal TMinus + tritVal TZero + tritVal TPlus))
