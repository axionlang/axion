-- Must FAIL with AX0004 (twice): a `let` value handed to a `%1` heap parameter is moved — the
-- callee frees it — so reading it afterwards is a use-after-move, exactly as for a parameter.
-- This used to pass the checker (only `%1` parameters and must-use values were tracked) and was
-- caught only by the native drop-balance verifier, as a misleading "Auto-Drop bug" (AX0910).
-- Reading BEFORE handing it over (`readFirst`) is fine.
eat :: String %1 -> Int
eat s = strLen s

inLet :: Int -> Int
inLet n = let s = show n in eat s + strLen s

readFirst :: Int -> Int
readFirst n = let s = show n in strLen s + eat s

main :: IO ()
main = do
  let s = show 12345
  putStrLn (show (eat s))
  putStrLn s
  putStrLn (show (inLet 7 + readFirst 7))
