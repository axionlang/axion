{-# LANGUAGE LinearTypes #-}

{- |
Module      : Axion.Prototype.Buffer

Phase 0 — semantic validation bench (spec §17). It is NOT the compiler.

Models Axion's central resource, the @Buffer U8 %1@ (Listings 2.1–2.2), as an
EDSL over GHC's @LinearTypes@ extension. Its sole aim is to validate,
in weeks and before writing a line of compiler, the /linearity rule/: every
@%1@ value is consumed __exactly once__. Contraction (using it twice) is
rejected by the typechecker — the bench analog of the own compiler's @AX0001@
diagnostic (use-after-consume).

Model: ownership (@%1@) is enforced by the operations' @%1@ /arrows/; the
runtime backing (a 'V.Vector') is irrelevant to what is validated here — Phase 0
validates the semantics, not performance. Borrow-elision, Auto-Drop and in-place
mutation are /compiler/ features (Phases 1–2), not expressible in GHC's
@LinearTypes@ (multiplicities only on arrows); here a read returns ownership
explicitly (consume-and-return), in the manner of @linear-base@.
-}
module Axion.Prototype.Buffer (
  Buffer,

  -- * Scoped allocation (ownership enters and leaves the continuation)
  withBuffer,

  -- * Linear operations (consume and return ownership)
  set,
  get,
  checksum,

  -- * Final consumption
  free,
)
where

import Data.Unrestricted.Linear (Ur (..))
import Data.Vector qualified as V
import Data.Word (Word32, Word8)

{- | A linear buffer of bytes. The constructor is private: only this module's
operations create and consume @Buffer@, ensuring that the @%1@ discipline is the
only door to the resource.

It is the @Buffer@ /handle/ that is linear (enforced by the operations' @%1@
arrows); the runtime backing is plain data, so the vector lives inside an 'Ur' —
@linear-base@'s unrestricted wrapper. Thus, when consuming a @Buffer %1@,
you read the vector with the normal "Data.Vector" operations without violating
the handle's linearity.
-}
newtype Buffer = Buffer (Ur (V.Vector Word8))

{- | Scoped allocation. The continuation receives a @Buffer %1@ that it __must__
consume exactly once (chaining 'set'/'get' and ending in 'free', or returning it
inside the result). It is the safe way to introduce linear ownership in the
prototype.
-}
withBuffer :: Int -> (Buffer %1 -> Ur a) %1 -> Ur a
withBuffer n k = k (Buffer (Ur (V.replicate n 0)))

{- | Writes a byte. Consumes the @Buffer@ and returns ownership — there are never
two live references to the same buffer (spec Fig. 2.1).
-}
set :: Int -> Word8 -> Buffer %1 -> Buffer
set i x (Buffer (Ur v)) = Buffer (Ur (v V.// [(i, x)]))

{- | Reads a byte. On the bench, a read consumes and returns ownership (@linear-base@
does the same); in the real compiler this would be an invisible /borrow elision/.
-}
get :: Int -> Buffer %1 -> (Ur Word8, Buffer)
get i (Buffer (Ur v)) = (Ur (v V.! i), Buffer (Ur v))

-- | Checksum (Listing 2.2). Reads all the bytes and returns ownership.
checksum :: Buffer %1 -> (Ur Word32, Buffer)
checksum (Buffer (Ur v)) =
  (Ur (V.foldl' (\acc b -> acc + fromIntegral b) 0 v), Buffer (Ur v))

{- | Consumes the buffer for good. It is the bench analog of the @free@ that
Auto-Drop would inject at the death point (Phases 1–2).
-}
free :: Buffer %1 -> ()
free (Buffer (Ur _)) = ()
