-- Multi-statement `do` block (IO): sequential (strict) desugaring into `let`s.
main :: IO ()
main = do
  putStrLn "one"
  putStrLn "two"
