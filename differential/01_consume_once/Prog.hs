{-# LANGUAGE LinearTypes #-}

-- Same scenario on the EDSL bench: the %1 Buffer is consumed once (free) → compiles.
module Prog where

import Axion.Prototype.Buffer (free, withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

useOnce :: Ur Word8
useOnce = withBuffer 8 (\buf -> case free buf of () -> Ur 0)
