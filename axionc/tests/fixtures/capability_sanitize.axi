-- OS capability layer (§pass): self-contained exercise of the String-producing
-- primitives (getEnv/runCapture/randHex/readDir/readFile — each allocs a heap
-- String that must be reclaimed exactly once) plus the Int-returning ones. Output
-- is environment-dependent; this fixture exists for the ASan/LSan gate
-- (scripts/sanitize.sh), which checks memory-safety + leak-freedom, not output.
main :: IO ()
main = do
  putStrLn (getEnv "PATH")
  putStrLn (runCapture "printf sanitize-ok")
  putStrLn (showInt (strLen (randHex 4)))
  putStrLn (showInt (strLen (readDir "/")))
  putStrLn (showInt (runStatus "true"))
  putStrLn (showInt (fileExists "/"))
  putStrLn (readFile "/etc/hostname")
