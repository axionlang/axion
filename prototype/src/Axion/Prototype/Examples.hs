{-# LANGUAGE LinearTypes #-}

{- |
Module      : Axion.Prototype.Examples

Usos __bem-tipados__ do 'Buffer' linear: cada um é um único /fio/ de posse
(@buf -> set -> checksum/get -> free@) que o typechecker aceita. Os
contra-exemplos (uso duplo) vivem em @prototype/test/negative@ e devem falhar.

Duas notas de Linear Haskell: (1) o fio usa @case ... of@, não @let@ — os
bindings @let@/@where@ do GHC não preservam a linearidade (forçariam
multiplicidade @Many@); (2) aplica-se com parênteses, não com @($)@, porque
@($)@ não atravessa uma seta @%1@.
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

{- | Aloca 8 bytes, escreve 42 na posição 0, calcula o checksum e liberta.
Espelha a Listagem 2.2: a posse flui num fio único, sem cópias.
-}
writeThenChecksum :: Ur Word32
writeThenChecksum =
  withBuffer
    8
    ( \buf ->
        case checksum (set 0 42 buf) of
          (sig, buf2) -> case free buf2 of () -> sig
    )

-- | Aloca 4 bytes, escreve 7 na posição 0, lê-o de volta e liberta.
firstByte :: Ur Word8
firstByte =
  withBuffer
    4
    ( \buf ->
        case get 0 (set 0 7 buf) of
          (b, buf2) -> case free buf2 of () -> b
    )

{- | Propriedade-andaime (Fase 0): aloca @n@ bytes (todos a 0), escreve @x@ em
@i@ e devolve o checksum. Como os restantes bytes são 0, o checksum é @x@.
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
