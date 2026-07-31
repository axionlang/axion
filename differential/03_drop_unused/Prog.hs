{-# LANGUAGE LinearTypes #-}

-- Same scenario on the EDSL bench: the %1 Buffer is never consumed → GHC rejects
-- (the linear continuation must use 'buf' exactly once).
module Prog where

import Axion.Prototype.Buffer (withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

dropIt :: Ur Word8
dropIt = withBuffer 8 (\buf -> Ur 0)
