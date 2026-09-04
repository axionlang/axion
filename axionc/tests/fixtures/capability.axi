-- OS capability layer (§pass): subprocess, env, randomness, filesystem — all as
-- typed builtins that reclaim their String results. The three backends must agree.
-- The test harness sets CAP_DIR to a unique temp dir and CAP_VAR to a known value.
dir :: String
dir = getEnv "CAP_DIR"

path :: String
path = strAppend dir "/note.txt"

main :: IO ()
main = do
  putStrLn (runCapture "printf ok")           -- ok
  putStrLn (showInt (runStatus "exit 7"))     -- 7
  putStrLn (getEnv "CAP_VAR")                  -- envworks
  putStrLn (showInt (strLen (randHex 16)))     -- 32
  putStrLn (showInt (makeDir dir))             -- 0
  putStrLn (showInt (writeFile path "roundtrip")) -- 0
  putStrLn (readFile path)                     -- roundtrip
  putStrLn (showInt (fileExists path))         -- 1
  putStrLn (showInt (removeFile path))         -- 0
