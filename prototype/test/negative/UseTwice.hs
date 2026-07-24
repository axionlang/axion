{-# LANGUAGE LinearTypes #-}

{- |
NÃO COMPILA POR DESIGN.

Este ficheiro é a garantia central da Fase 0 escrita como teste executável:
um @Buffer %1@ usado __duas vezes__ tem de ser rejeitado pelo typechecker —
o análogo, na bancada, do diagnóstico @AX0001@ (uso-após-consumo) do
compilador próprio.

@./scripts/check-negative.sh@ compila-o e __exige que a compilação falhe__
com um erro de multiplicidade. Se um dia isto compilar, a linearidade deixou
de estar a ser imposta e o CI parte.
-}
module UseTwice where

import Axion.Prototype.Buffer (free, withBuffer)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)

-- 'buf' é consumido pelo primeiro 'free buf' e depois usado OUTRA VEZ no
-- segundo. A contracção (usar duas vezes) é proibida para todo o %1 => o GHC
-- rejeita com um erro de multiplicidade. É o análogo de AX0001.
useTwice :: Ur Word8
useTwice =
  withBuffer
    8
    ( \buf ->
        case free buf of
          () -> case free buf of -- <-- ERRO: 'buf' já foi consumido acima
            () -> Ur 0
    )
