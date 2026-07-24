{-# LANGUAGE LinearTypes #-}

-- Mesmo cenário na bancada EDSL: o Buffer %1 nunca é consumido → o GHC rejeita
-- (a continuação linear tem de usar 'buf' exactamente uma vez).
module Prog where

import Axion.Prototype.Buffer (withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

dropIt :: Ur Word8
dropIt = withBuffer 8 (\buf -> Ur 0)
