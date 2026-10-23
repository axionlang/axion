-- chr: the byte n as a 1-char String (inverse of charAt). Builds a byte from a runtime Int (the lexer
-- also has the `\e`/`\xNN` escapes for literals; `chr` is for computed values). Each result is a fresh heap String consumed by
-- putStr → drop-tracked, leak-free. Prints "A" then an ESC-bracket-J clear sequence.
main :: IO ()
main = do
  putStr (chr 65)
  putStr (strAppend (chr 27) "[2J")
