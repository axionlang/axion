-- The interpreter now STREAMS stdout (like the native backends) instead of buffering it
-- to the end, so output produced before `exitWith` is not lost. All backends: prints the
-- line, then exits 4.
main :: IO ()
main = do
  putStrLn "printed before exit"
  exitWith 4
