-- Pins that the prefix-minus-literal fold did NOT change existing parses:
--   `a - 3` stays binary subtraction (not application `a (-3)`),
--   `f . g`  stays compose (the `.` operator),
--   `[-1,-2,-3]` negative literals in a list still read as elements.
inc :: Int -> Int
inc x = x + 1

dbl :: Int -> Int
dbl x = x * 2

sumList :: List Int -> Int
sumList xs = case xs of
  Nil -> 0
  Cons h t -> h + sumList t

main :: IO ()
main = do
  putStrLn (showInt (let a = 10 in a -3))
  putStrLn (showInt ((inc . dbl) 5))
  putStrLn (showInt (sumList [-1, -2, -3]))
