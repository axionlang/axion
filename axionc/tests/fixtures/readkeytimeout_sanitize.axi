-- readKeyTimeout: like readKey, but wait at most N ms for a byte (else ""). On a pipe (the test
-- harness) the tty setup is a no-op and the bytes are already available, so `printf 'xy'` feeds two
-- keys and both reads return at once. Each returned String is a fresh heap value consumed by putStr
-- → drop-tracked, leak-free. A generous 1000 ms timeout keeps the pipe-fed test deterministic.
main :: IO ()
main = do
  a <- readKeyTimeout 1000
  b <- readKeyTimeout 1000
  putStr a
  putStr b
