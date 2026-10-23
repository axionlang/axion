-- Regression: `'\xNN'` char literals (hex byte). Before the lexer fix the char-literal regex rejected
-- the 4-char `\xNN` escape, so `'\x1b'` matched no token and the stray quotes drove the CST recovery
-- into an infinite loop (the compiler hung). `'\x1b'` == 27 (ESC), `'\x41'` == 65 ('A'), like the string
-- escape `"\x1b"` and `chr`. Prints "27 65 97".
main :: IO ()
main = do
  putStr (showInt ('\x1b'))
  putStr (strAppend " " (showInt ('\x41')))
  putStr (strAppend " " (showInt ('\x61')))
