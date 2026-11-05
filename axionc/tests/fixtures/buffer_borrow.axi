-- buffer_borrow.axi — the `borrow <buf> as <p> in <body>` FFI scope (§18). It leases the buffer's
-- DATA pointer as `p` for the block, keeps the buffer LIVE across `body` (so a C call reading
-- through `p` can't be freed early), then reclaims the buffer when the block ends — removing the
-- "use buf after the FFI call" dance a raw `bufPtr` otherwise needs. Here the body is pure so it
-- runs on every backend: `p - p` is 0 regardless of the pointer's value (interp models it as 0,
-- native as a real address), and the point under test is that the buffer is freed exactly once at
-- block end (LSan-clean) and `p` is its data address.
useBuf :: Buffer a -> Int
useBuf b = borrow b as p in p - p

main :: IO ()
main =
  let b = newBuffer 16 in
  let w = pokeU32 b 0 777 in
  putStrLn (showInt (useBuf b + w))
