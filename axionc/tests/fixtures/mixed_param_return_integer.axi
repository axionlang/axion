-- Regression: the conditional param-return UAF over an INTEGER param (the condRet shape), now
-- fixed by the REUSE-GATED copy (R-3, docs/call-site-ownership.md). `clampNeg` returns its
-- Integer param bare on one branch + fresh on another; `useI` reuses `n` after the call, so the
-- call-site reuse gate copies the bare return via `axion_bignum_copy` (String uses strAppend).
-- A fold accumulator, whose `acc` is NEVER reused after the combiner call, is left uncopied —
-- so RSA/fold performance is untouched (the first, ungated Integer attempt cloned per iteration).
clampNeg :: Integer -> Integer
clampNeg x = if x < fromInt 0 then fromInt 0 else x

useI :: Integer -> Integer
useI n =
  let picked = clampNeg n in
  n + fromInt 1

main :: IO ()
main = putStrLn (showInteger (useI (fromInt 5)))
