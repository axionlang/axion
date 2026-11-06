-- layout_paren_case_multiline.axi — the multi-line nested `(case … )` form: the `)` on the last
-- alternative's line closes the inner `of` block before the outer case continues.
f :: Int -> Int -> Int
f a b = case a of
  0 -> (case b of
    0 -> 1
    _ -> 2)
  _ -> 3

main :: IO ()
main = do
  putStrLn (showInt (f 0 0))   -- 1
  putStrLn (showInt (f 0 5))   -- 2
  putStrLn (showInt (f 9 9))   -- 3
