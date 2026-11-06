-- layout_paren_let.axi — a parenthesized `let … in …` as a sub-expression: the `)` closes the
-- (already `in`-closed) let context cleanly, and a nested `(let … in …)` inside it.
main :: IO ()
main = do
  let r = (let x = 10 in x + 1)
  let s = (let a = 2 in (let b = 3 in a * b))
  putStrLn (showInt r)   -- 11
  putStrLn (showInt s)   -- 6
