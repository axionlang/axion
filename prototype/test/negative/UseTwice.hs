{-# LANGUAGE LinearTypes #-}

{- |
DOES NOT COMPILE BY DESIGN.

This file is Phase 0's central guarantee written as an executable test:
a @Buffer %1@ used __twice__ must be rejected by the typechecker —
the bench analog of the own compiler's @AX0001@ diagnostic (use-after-consume).

@./scripts/check-negative.sh@ compiles it and __requires the compilation to fail__
with a multiplicity error. If this ever compiles, linearity has stopped being
enforced and CI breaks.
-}
module UseTwice where

import Axion.Prototype.Buffer (free, withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

-- 'buf' is consumed by the first 'free buf' and then used AGAIN in the second.
-- Contraction (using it twice) is forbidden for every %1 => GHC rejects with a
-- multiplicity error. It is the analog of AX0001.
useTwice :: Ur Word8
useTwice =
  withBuffer
    8
    ( \buf ->
        case free buf of
          () -> case free buf of -- <-- ERROR: 'buf' was already consumed above
            () -> Ur 0
    )
