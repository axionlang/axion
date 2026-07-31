module Main (main) where

import Axion.Prototype.Examples (firstByte, writeThenChecksum)
import Data.Unrestricted.Linear (Ur (..))

main :: IO ()
main = do
  let Ur c = writeThenChecksum
      Ur b = firstByte
  putStrLn "Axion · Phase 0 — EDSL prototype (semantic validation of linearity)"
  putStrLn ("  checksum after set 42 @0 : " <> show c)
  putStrLn ("  get 0 after set 7 @0     : " <> show b)
  putStrLn "OK: the linear thread compiled and ran (a %1 Buffer, consumed once)."
