-- ASan/LSan gate for the stdin/tty String producers (§pass): readLine and readSecret
-- each allocate a fresh heap String that must be reclaimed exactly once. Reads a line
-- and an echo-off secret (both "" at EOF when no input is piped), forcing the alloc +
-- reclaim path through strAppend/strLen. Output is input-dependent and not asserted;
-- this fixture exists for scripts/sanitize.sh, which checks memory-safety + leak-freedom.
main :: IO ()
main = do
  putStrLn (strAppend "line:" (readLine 0))
  putStrLn (strAppend "secret-len:" (showInt (strLen (readSecret 0))))
