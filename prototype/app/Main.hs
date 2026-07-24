module Main (main) where

import Axion.Prototype.Examples (firstByte, writeThenChecksum)
import Data.Unrestricted.Linear (Ur (..))

main :: IO ()
main = do
  let Ur c = writeThenChecksum
      Ur b = firstByte
  putStrLn "Axión · Fase 0 — protótipo EDSL (validação semântica de linearidade)"
  putStrLn ("  checksum após set 42 @0 : " <> show c)
  putStrLn ("  get 0 após set 7 @0     : " <> show b)
  putStrLn "OK: o fio linear compilou e correu (um Buffer %1, consumido uma vez)."
