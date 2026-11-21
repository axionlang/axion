-- A program's own `.&.` and `xor` (here over Bool) replace the built-in ones in its code, while
-- the prelude's `popCount` / `complement` keep the built-in Int operators: the prelude is
-- type-checked even where it is unused, so a user operator leaking into it broke every program
-- that defined one.
infixl 7 .&.
(.&.) :: Bool -> Bool -> Bool
(.&.) a b = if a then b else False

xor :: Bool -> Bool -> Bool
xor a b = if a then not b else b

main :: IO ()
main = do
  putStrLn (if True .&. False then "y" else "n")
  putStrLn (if xor True False then "y" else "n")
  putStrLn (showInt (popCount 7 + complement 0))
