{-# LANGUAGE LinearTypes #-}

-- Mesmo cenário na bancada EDSL: o Buffer %1 é consumido DUAS vezes → o GHC
-- rejeita com erro de multiplicidade (o análogo de AX0001).
module Prog where

import Axion.Prototype.Buffer (free, withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

useTwice :: Ur Word8
useTwice =
  withBuffer 8 (\buf -> case free buf of () -> case free buf of () -> Ur 0)
