-- `complement` and `popCount` (Haskell's `Data.Bits` names), prelude functions over `Int`:
-- `complement x` flips every bit (`xor x (-1)`); `popCount x` counts the set bits of the 64-bit
-- two's-complement value, so a negative number counts its sign bits too.
main :: IO ()
main = do
  putStrLn (showInt (complement 0))
  putStrLn (showInt (complement 5))
  putStrLn (showInt (complement (-6)))
  putStrLn (showInt (popCount 0))
  putStrLn (showInt (popCount 7))
  putStrLn (showInt (popCount 1024))
  putStrLn (showInt (popCount (-1)))
  putStrLn (showInt (popCount (shiftL 1 63)))
  putStrLn (showInt (popCount (complement 255)))
  putStrLn (showInt (popCount (0xFF .&. complement 0x0F)))
