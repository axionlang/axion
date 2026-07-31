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
    "Axion · Phase 0 — semantic validation bench"
    [ testGroup
        "Unit (well-typed linear threads)"
        [ testCase "checksum after set 42 @0 == 42" $
            case writeThenChecksum of Ur c -> c @?= 42
        , testCase "get 0 after set 7 @0 == 7" $
            case firstByte of Ur b -> b @?= 7
        ]
    , -- Property scaffold (§17: "the scaffold, not the tests yet"). In
      -- Phase 1 this group grows into typechecker preservation/progress.
      testGroup
        "Properties (scaffold)"
        [ testProperty "checksum of a zero buffer with x written at 0 equals x" $
            \(Positive n) (x :: Word8) ->
              checksumWith n 0 x === fromIntegral x
        ]
    ]
