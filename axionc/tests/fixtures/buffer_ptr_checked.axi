-- buffer_ptr_checked.axi — `bufPtrN buf minBytes` (§18 FFI hardening): a bounds-checked data-pointer
-- accessor. C reads/writes through the raw pointer unchecked, so handing it a too-small buffer is a
-- silent out-of-bounds access; `bufPtrN` aborts first if the buffer holds fewer than `minBytes`,
-- turning heap corruption into a clean failure. Here every request is in-bounds (buffer is 16, asks
-- for ≤ 16), so it returns the data address; `p - p` nets it to 0 so output is backend-stable (the
-- pointer value itself differs by backend — interp models it as 0, native is a real address).

main :: IO ()
main = do
  let b = newBuffer 16
  let w = pokeU32 b 0 11 + pokeU32 b 4 22
  let p16 = bufPtrN b 16
  let p4 = bufPtrN b 4
  putStrLn (showInt (peekU32 b 0 + w + (p16 - p16)))
  putStrLn (showInt (peekU32 b 4 + (p4 - p4)))
