-- chr: the byte n as a 1-char String (inverse of charAt). Used to build ANSI escapes in-language
-- (chr 27 = ESC) since the lexer has no `\e`/`\xNN`. Each result is a fresh heap String consumed by
-- putStr → drop-tracked, leak-free. Prints "A" then an ESC-bracket-J clear sequence.
main :: IO ()
main = do
  putStr (chr 65)
  putStr (strAppend (chr 27) "[2J")
