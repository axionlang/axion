{-# LANGUAGE LinearTypes #-}

-- Same scenario on the EDSL bench: the %1 Buffer is consumed TWICE → GHC
-- rejects with a multiplicity error (the analog of AX0001).
module Prog where

import Axion.Prototype.Buffer (free, withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

useTwice :: Ur Word8
useTwice =
  withBuffer 8 (\buf -> case free buf of () -> case free buf of () -> Ur 0)
