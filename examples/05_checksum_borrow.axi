-- Target program 5/5 — L1 borrow elision: read without consuming (Listing 2.2).
-- Phase 1 success: 'checksum' has no %1 on its argument => the compiler borrows it
-- as a slice; ownership never leaves the caller. 'process' reads and then
-- passes the SAME ownership to 'encrypt' — no copy, no AX0001.

checksum :: Buffer U8 -> U32            -- borrow: no %1, 'buf' is NOT consumed
checksum buf = foldBytes (+) 0 buf

encrypt :: Buffer U8 %1 -> Buffer U8 %1 -- consome e devolve a posse
encrypt buf = imperative $ do xorInPlace buf 0x5A

process :: Buffer U8 %1 -> (U32, Buffer U8 %1)
process buf =
  let sig = checksum buf   -- implicit borrow: 'buf' is STILL owned here
  in  (sig, encrypt buf)   -- ownership flows to 'encrypt'; no clone, no AX0001
