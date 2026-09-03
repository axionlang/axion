-- Multi-param reclamation: a concrete `Either Integer Integer` that DISCARDS a heap payload on
-- one branch. Before the multi-param poly-field-resolution fix this BAD-FREED the discarded
-- Integer (the resolver split `Either$Integer$Integer` as head + `Integer$Integer` and flat-freed
-- a boxed value) while the verifier reported clean. Now each poly field resolves to its correct
-- type argument (Left→arg0, Right→arg1) → `axion_bignum_free`. Sound + leak-free on every backend.
fromLeftI :: Integer -> Either Integer Integer -> Integer
fromLeftI d e = case e of
  Left x -> x
  Right y -> d

fromRightI :: Integer -> Either Integer Integer -> Integer
fromRightI d e = case e of
  Left x -> d
  Right y -> y

main :: IO ()
main = putStrLn (showInteger
  (fromLeftI (fromInt 0) (Left (fromInt 8))
   + fromRightI (fromInt 0) (Left (fromInt 5))))
