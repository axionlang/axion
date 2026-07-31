-- Target program 3/5 — L1 the heart of Phase 1: end-to-end linearity.
-- Success: 'main' compiles and runs; the commented `useTwice` version is REJECTED
-- with AX0001 (use-after-consume). It is the same invariant the Phase 0 EDSL
-- bench already validates (prototype/src/Axion/Prototype/Buffer.hs).

encrypt :: Buffer U8 %1 -> Buffer U8 %1   -- consumes and returns ownership
encrypt buf = imperative $ do
  xorInPlace buf 0x5A

-- Ownership goes in (%1) and out (%1): a single thread, never cloned.
run :: Buffer U8 %1 -> Buffer U8 %1
run buf =
  let buf' = encrypt buf     -- 'buf' dies here; 'buf'' inherits ownership
  in  buf'

-- EXPECTED ERROR (AX0001) — uncommenting should fail compilation:
-- useTwice :: Buffer U8 %1 -> (Buffer U8 %1, Buffer U8 %1)
-- useTwice buf = (encrypt buf, encrypt buf)   -- 'buf' consumed twice

main :: IO ()
main = withBuffer 4096 (\buf -> free (run buf))
