-- An owned String used inside a non-tail `if` whose branches free it at its last use (one
-- branch returns it as is, so it is copied there) is gone after the `if`. A later free of it
-- at the end of the scope used to double-free (AX0910) — for a `let`-bound value and for a
-- field taken out of an owned `case` scrutinee alike.

data Req = Req String String

parse :: String -> Either Int Req
parse raw = if strLen raw > 0 then Right (Req "GET" raw) else Left 400

reqFile :: String -> String
reqFile raw = case parse raw of
  Left code -> ""
  Right r -> case r of
    Req m p -> strAppend "root" (if hasSuffix "/" p then strAppend p "index.html" else p)

withIndex :: String -> String
withIndex raw = do
  let p = strAppend raw ""
  strAppend "root" (if hasSuffix "/" p then strAppend p "index.html" else p)

main :: IO ()
main = do
  putStrLn (reqFile "/a/")
  putStrLn (reqFile "/b.txt")
  putStrLn (withIndex "/c/")
  putStrLn (withIndex "/d.css")
