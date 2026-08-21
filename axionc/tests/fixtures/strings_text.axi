-- Char-level string processing (§text): the byte primitives strLen/charAt/substr
-- and the prelude splitters words/lines/splitOn, plus a Show String instance so a
-- List String prints with quotes. Byte-oriented (ASCII); charAt returns the byte
-- codepoint (or -1 out of bounds). Identical on interp == cranelift == llvm.
main :: IO ()
main = do
  putStrLn (show (strLen "hello"))
  putStrLn (show (charAt 1 "hello"))
  putStrLn (show (charAt 9 "hello"))
  putStrLn (substr 6 5 "hello world")
  putStrLn (show (words "  the  quick brown  "))
  putStrLn (show (lines "a\nb\nc\n"))
  putStrLn (show (splitOn 44 "x,,y"))
  putStrLn (unwords (words "round  trip"))
  putStrLn (show (length (words "one two three four")))
