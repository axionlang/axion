-- readKey: read raw single keypresses (one byte each, no Enter) as 1-char Strings, echo them.
-- On a pipe (the test harness) readKey degrades to a plain 1-byte read, so `printf 'xy'` feeds two
-- keys. Each returned String is a fresh heap value consumed by putStr → drop-tracked, leak-free.
main :: IO ()
main = do
  a <- readKey 0
  b <- readKey 0
  putStr a
  putStr b
