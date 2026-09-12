-- Regression: the prelude `sort`/`sortBy` over a HEAP element type (String). The old quicksort
-- filtered the tail TWICE (a heap duplication no `%1` list can satisfy) → rejected by AX0912
-- (`sort$String`). Now a one-pass partition (`partitionLe`/`partitionBy`, no capturing lambda)
-- consumes its `%1` list once and reclaims each element, so it compiles + runs leak-free on
-- every backend.
byLen :: String -> String -> Bool
byLen a b = strLen a < strLen b

main :: IO ()
main = do
  putStr (unlines (sort (Cons "pear" (Cons "fig" (Cons "kiwi" (Cons "date" Nil))))))
  putStr (unlines (sortBy byLen (Cons "ccc" (Cons "a" (Cons "dddd" (Cons "bb" Nil))))))
