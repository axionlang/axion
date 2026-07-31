{-# LANGUAGE LinearTypes #-}

{- |
Module      : Axion.Prototype.Examples

__Well-typed__ uses of the linear 'Buffer': each is a single ownership /thread/
(@buf -> set -> checksum/get -> free@) that the typechecker accepts. The
counter-examples (double use) live in @prototype/test/negative@ and must fail.

Two Linear Haskell notes: (1) the thread uses @case ... of@, not @let@ — GHC's
@let@/@where@ bindings do not preserve linearity (they would force multiplicity
@Many@); (2) apply with parentheses, not with @($)@, because @($)@ does not cross
a @%1@ arrow.
-}
module Axion.Prototype.Examples (
  writeThenChecksum,
  firstByte,
  checksumWith,
)
where

import Axion.Prototype.Buffer (checksum, free, get, set, withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word32, Word8)

{- | Allocates 8 bytes, writes 42 at position 0, computes the checksum and frees.
Mirrors Listing 2.2: ownership flows in a single thread, without copies.
-}
writeThenChecksum :: Ur Word32
writeThenChecksum =
  withBuffer
    8
    ( \buf ->
        case checksum (set 0 42 buf) of
          (sig, buf2) -> case free buf2 of () -> sig
    )

-- | Allocates 4 bytes, writes 7 at position 0, reads it back and frees.
firstByte :: Ur Word8
firstByte =
  withBuffer
    4
    ( \buf ->
        case get 0 (set 0 7 buf) of
          (b, buf2) -> case free buf2 of () -> b
    )

{- | Scaffold property (Phase 0): allocates @n@ bytes (all 0), writes @x@ at
@i@ and returns the checksum. Since the remaining bytes are 0, the checksum is @x@.
-}
checksumWith :: Int -> Int -> Word8 -> Word32
checksumWith n i x =
  case withBuffer
    n
    ( \buf ->
        case checksum (set i x buf) of
          (sig, buf2) -> case free buf2 of () -> sig
    ) of
    Ur c -> c
