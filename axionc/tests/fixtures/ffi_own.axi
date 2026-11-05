-- ffi_own.axi — per-argument FFI ownership (§18). `Own T` marks an arg whose ownership transfers
-- to C: the value is CONSUMED by the call (Axión does not free it afterwards, and reusing it is a
-- use-after-move error); every other arg stays `Borrow` (the default — Axión keeps it and frees
-- once). Here `sink` takes ownership of a fresh heap String and never touches it again, so the
-- move accounting is balanced (no double-free, no leak the verifier can see). `peek` borrows.
--
-- Compile-/verify-checked only (the C symbols are an unsafe-island contract, not linked here).

foreign "lib.so" sink = "c_take_string" :: Own String -> Int
foreign "lib.so" peek = "c_read_string" :: String -> Int

-- transfers ownership of the fresh String to C (consumes it); returns C's status code.
give :: String -> Int
give s = sink s

-- borrows: reads the String twice, still owns it, returns its length afterwards.
borrowTwice :: String -> Int
borrowTwice s =
  let a = peek s in
  let b = peek s in
  strLen s + (a - a) + (b - b)

main :: IO ()
main =
  let total = give (strAppend "hello " "world") + borrowTwice "kept" in
  putStrLn (showInt (total - total))
