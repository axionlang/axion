-- Graceful-failure contract: sessions bypass the native-candidacy filter, so a
-- session whose shape is OUTSIDE the native subset (here the block value is a
-- function call, `inc r`, not a plain var/arithmetic) must FAIL LOUDLY under
-- native codegen — never silently miscompile. The interpreter stays correct:
-- inc (2*21) = 43. Under `--backend cranelift`/`--release` it is rejected with a
-- clear "outside the native subset" message (fall back to the interpreter).
inc :: Int -> Int
inc x = x + 1

worker :: Ep (Recv Int (Send Int End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (n + n)
  close d3

main :: Int
main = bound $ do
  c <- spawn worker
  c2 <- send c 21
  (r, c3) <- recv c2
  close c3
  inc r
