-- layout_semi_case.axi — explicit `;` separates block items on one line. `case` alternatives
-- (`0 -> "z" ; 1 -> "o" ; _ -> "m"`) and the parenthesized form combined with bracket-aware layout.
cls :: Int -> String
cls n = case n of 0 -> "z" ; 1 -> "o" ; _ -> "m"

g :: Int -> Int -> Int
g a b = case a of
  0 -> (case b of 0 -> 1 ; _ -> 2)
  _ -> 3

main :: IO ()
main = do
  putStrLn (cls 0)              -- z
  putStrLn (cls 1)              -- o
  putStrLn (cls 9)              -- m
  putStrLn (showInt (g 0 0))    -- 1
  putStrLn (showInt (g 0 5))    -- 2
  putStrLn (showInt (g 7 7))    -- 3
