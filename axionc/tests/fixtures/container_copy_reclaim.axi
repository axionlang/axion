-- R-5 (docs/call-site-ownership.md): the conditional param-return UAF over a CONTAINER.
-- `tagOr` returns its `Lst` param BARE on one branch and a FRESH `Lst` on another (the
-- `condRet`/`fromMaybe` shape), so the result is a runtime alias-or-fresh; `use2` REUSES
-- `xs` after the call, so both the result and the arg are live and dropped. Without a
-- container deep-copy this class was fail-closed (the drop-verifier rejects the alias,
-- AX0910). R-5 emits a per-type deep-copier `axion_copy_Lst`, and the call-site reuse gate
-- copies the bare return (`axion_copy_Lst s`) so the return is uniformly owned and the param
-- borrowed — sound on every backend, ASan/LSan clean. A never-reused container return keeps
-- its zero-cost move (no copier emitted at all unless a real reuse needs it).
data Lst = LNil | LCons Int Lst

sumL :: Lst -> Int
sumL xs = case xs of
  LNil -> 0
  LCons x ys -> x + sumL ys

build :: Int -> Lst
build n = if n == 0 then LNil else LCons n (build (n - 1))

tagOr :: Lst -> Lst
tagOr s = if sumL s == 0 then LCons 42 LNil else s

use2 :: Lst -> Int
use2 xs =
  let r = tagOr xs in
  sumL r + sumL xs

main :: IO ()
main = do
  putStrLn (showInt (use2 (build 3)))
  putStrLn (showInt (use2 LNil))
