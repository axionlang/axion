-- A program's own `xor` (here on Bool) wins over the built-in bitwise one, infix and prefix.
xor :: Bool -> Bool -> Bool
xor a b = if a then not b else b

main :: IO ()
main = do
  putStrLn (if True `xor` False then "yes" else "no")
  putStrLn (if xor True True then "yes" else "no")
