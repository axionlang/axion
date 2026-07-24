{-# LANGUAGE LinearTypes #-}

-- Mesmo cenário na bancada EDSL: o Buffer %1 é consumido uma vez (free) → compila.
module Prog where

import Axion.Prototype.Buffer (free, withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

useOnce :: Ur Word8
useOnce = withBuffer 8 (\buf -> case free buf of () -> Ur 0)
