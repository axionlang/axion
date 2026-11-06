-- layout_paren_do.axi — a parenthesized `do` block as an expression: the closing `)` ends the do
-- block. (The whole `main` body is a `(do …)`.)
main :: IO ()
main = (do
  putStrLn "a"
  putStrLn "b")
