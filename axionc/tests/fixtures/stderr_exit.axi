-- §CLI: ePutStrLn writes to stderr; `die` prints to stderr and exits non-zero. stdout
-- stays empty. (The interpreter buffers stdout and prints at the end, so anything sent
-- to *stdout* before an exit would be lost there — hence prompts/errors use stderr.)
main :: IO ()
main = do
  ePutStrLn "diagnostic to stderr"
  die "fatal: boom"
