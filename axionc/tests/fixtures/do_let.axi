-- do-`let`: a `let x = e` statement (no `in`) binds a pure value for the rest of a do-block,
-- interleaved with effectful statements; desugars to `let x = e in <rest>`. Lets effectful code
-- stay a clean do-block instead of a let-chain. Both parsers (CST default + recovery) agree.
twice :: String -> String
twice s = strAppend s s
main :: IO ()
main = do
  let a = twice "ab"
  putStrLn a
  let b = strAppend a "!"
  putStrLn b
  let n = charAt 0 b
  putStrLn (showInt n)
