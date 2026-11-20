-- Bitwise Int operators (Haskell's Data.Bits names): `.&.` `.|.` `xor` `shiftL` `shiftR`, infix or
-- prefix, with Haskell's fixities (shifts 8, `.&.` 7, `xor` 6, `.|.` 5). A shift amount is taken
-- modulo 64 on every backend (`shiftR` is arithmetic); `xor x (-1)` is the complement.
pix :: Int -> Int -> Int -> Int
pix r g b = (r `shiftL` 16) .|. (g `shiftL` 8) .|. b

red :: Int -> Int
red p = (p `shiftR` 16) .&. 255

main :: IO ()
main = do
  let p = pix 18 52 86
  putStrLn (showInt p)
  putStrLn (showInt (red p))
  putStrLn (showInt (p .&. 255 .|. 1 `shiftL` 4))
  putStrLn (showInt (xor 12 10))
  putStrLn (showInt (12 `xor` 10 .&. 6))
  putStrLn (showInt (shiftR (0 - 16) 2))
  putStrLn (showInt (shiftL 1 65))
  putStrLn (showInt (shiftL 1 (0 - 1)))
  putStrLn (showInt (xor 5 (0 - 1)))
