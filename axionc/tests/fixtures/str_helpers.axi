-- Prelude Str helpers + readInt + boolean operators, over all backends.
main :: IO ()
main = do
  putStrLn (show (strLen (trim "  ab  ")))
  putStrLn (show (hasPrefix "fo" "foo"))
  putStrLn (show (hasSuffix "oo" "foo"))
  putStrLn (show (isDigit 53))
  putStrLn (show (readInt "42"))
  putStrLn (show (readInt "4x"))
  putStrLn (dirName "a/b/c")
  putStrLn (baseName "a/b/c")
  putStrLn (show (True && False))
  putStrLn (show (False || True))
