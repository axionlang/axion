{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

import Axion.Prototype.Examples (checksumWith, firstByte, writeThenChecksum)
import Data.Unrestricted.Linear (Ur (..))
import Data.Word (Word8)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Test.Tasty.QuickCheck (Positive (..), testProperty, (===))

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Axión · Fase 0 — bancada de validação semântica"
    [ testGroup
        "Unidade (fios lineares bem-tipados)"
        [ testCase "checksum após set 42 @0 == 42" $
            case writeThenChecksum of Ur c -> c @?= 42
        , testCase "get 0 após set 7 @0 == 7" $
            case firstByte of Ur b -> b @?= 7
        ]
    , -- Andaime de propriedades (§17: «o andaime, não os testes ainda»). Na
      -- Fase 1 este grupo cresce para preservação/progresso do typechecker.
      testGroup
        "Propriedades (andaime)"
        [ testProperty "checksum de buffer de zeros com x escrito em 0 vale x" $
            \(Positive n) (x :: Word8) ->
              checksumWith n 0 x === fromIntegral x
        ]
    ]
