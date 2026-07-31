-- Graceful-failure contract: sessions bypass the native-candidacy filter, so a
-- session whose shape is OUTSIDE the native subset must FAIL LOUDLY under native
-- codegen — never silently miscompile. Here the block value is a `case`
-- expression, which the session generator does not lower. The interpreter stays
-- correct (r = 42 → 100); under `--backend cranelift`/`--release` it is rejected
-- with a clear "outside the native subset" message (fall back to the interpreter).
-- (A value-position CALL like `fib r` IS supported — see session_run_fib.)
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
  case r of
    42 -> 100
    _ -> r
