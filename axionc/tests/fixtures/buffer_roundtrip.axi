-- buffer_roundtrip.axi — first-class Buffer (§4): the peek/poke family over every width + f64.
-- A Buffer is a linear byte buffer: `newBuffer` allocates it, every peek/poke BORROWS it (so it
-- stays usable across all of them), and it is auto-reclaimed (axion_buf_free) when it dies at the
-- end of `main` — LSan-clean. The pokes are threaded into `w` (each returns 0) so strict evaluation
-- runs every write before the reads; peeks decode the same little-endian bytes. All backends agree.

main :: IO ()
main = do
  let b = newBuffer 32
  let w = pokeU8 b 0 200 + pokeU16 b 2 40000 + pokeU32 b 4 4000000000 + pokeU64 b 8 1234567890123 + pokeF64 b 16 2.5
  putStrLn (showInt (peekU8 b 0 + w))
  putStrLn (showInt (peekU16 b 2))
  putStrLn (showInt (peekU32 b 4))
  putStrLn (showInt (peekU64 b 8))
  putStrLn (showFloat (peekF64 b 16))
