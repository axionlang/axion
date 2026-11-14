-- Files are linear `File`s: opened, read in chunks into byte `Buffer`s, closed exactly once on
-- every path, including when the open failed (a `File` then carries the errno). The buffers are
-- freed automatically. Reads this fixture itself and sums its bytes in 64-byte chunks (found
-- from the repo root or from axionc/, so every gate runs the full read).

selfPath :: Int -> String
selfPath d =
  if fileExists "tests/fixtures/file_read_chunks.axi" == 1
    then "tests/fixtures/file_read_chunks.axi"
    else "axionc/tests/fixtures/file_read_chunks.axi"

sumChunks :: File -> Int -> Int
sumChunks f acc = do
  let b = fileRead f 64
  if bufLen b == 0 then acc else sumChunks f (acc + sumBytes b)

report :: String -> String
report path = do
  let f = fileOpenRaw path
  if fileErrno f /= 0
    then do
      let e = fileErrno f
      fileClose f
      strAppend "error " (showInt e)
    else if fileSize f < 0
      then do
        let e = 0 - fileSize f
        fileClose f
        strAppend "not a file " (showInt e)
      else do
        let n = fileSize f
        let s = sumChunks f 0
        fileClose f
        strAppend (strAppend (showInt n) " bytes, sum ") (showInt s)

main :: IO ()
main = do
  putStrLn (report (selfPath 0))
  putStrLn (report "no_such_file.axi")
  putStrLn (report ".")
