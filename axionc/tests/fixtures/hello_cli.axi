-- Phase A capability spike (§pass): a real CLI shape — dispatch on argv, read the
-- environment, and shell out — proving the OS capability layer end-to-end on every
-- backend. The harness runs it as `… -- greet world` with HELLO_HOME set.
-- Uses the indexed `getArg` (each a fresh copy) rather than splitting argv into a
-- List String, which would trip native heap-element aliasing.
main :: IO ()
main = do
  putStrLn (strAppend "cmd=" (getArg 0))
  putStrLn (strAppend "arg=" (getArg 1))
  putStrLn (strAppend "missing=" (getArg 5))
  putStrLn (strAppend "home=" (getEnv "HELLO_HOME"))
  putStrLn (runCapture "printf spawned")
