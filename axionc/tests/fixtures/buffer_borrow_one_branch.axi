-- A fresh Buffer handed to C through a `borrow` scope on ONE branch (which frees it when the scope
-- ends) and simply dead on the other must be freed on that other branch too — it leaked there
-- (AX0911 Unbalanced; axmpv's `feedAudio` at the end of an audio stream).
use :: Int -> Int
use k =
  let b = newBuffer 16 in
  let got = pokeU64 b 0 k + peekU64 b 0 in
  if got < 4 then 1 else (borrow b as p in p * 0 + got)

main :: IO ()
main = putStrLn (showInt (use 2) ++ " " ++ showInt (use 9))
