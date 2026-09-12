-- Regression for the conditional param-return UAF. A non-`%1` String param returned BARE on
-- one branch while ANOTHER branch returns a FRESH value (the `condRet`/`fromMaybe`/`chomp`
-- shape) makes the result a runtime alias-or-fresh: a caller that REUSES the arg dropped the
-- result as fresh and freed the still-live arg → native use-after-free (interp and the drop
-- verifier both missed it). The compiler now copy-normalizes the bare-param return
-- (`strAppend x ""`) so the return is uniformly owned and the param is borrowed — sound on
-- every backend. (A pure param-OR-param return, `if c then d else s`, is already handled by
-- the interprocedural alias summary and is deliberately NOT rewritten.)
tagOr :: String -> String -> String
tagOr fallback s = if strLen s == 0 then strAppend "<" (strAppend fallback ">") else s

use2 :: String -> String
use2 name = strAppend (tagOr "none" name) (strAppend "|" name)

main :: IO ()
main = do
  putStrLn (use2 "bob")
  putStrLn (use2 "")
