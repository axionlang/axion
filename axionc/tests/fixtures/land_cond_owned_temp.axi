-- Landing fixture for the MIXED conditional-owned-temp reclamation (the #1 flagship gotcha).
-- A `let x = if c then <fresh heap> else <borrowed value>` binds a value that is OWNED on one
-- branch (a fresh `strAppend`/bignum result) but a BORROWED alias on the other (a parameter).
-- Such an `x` is conditionally-owned: a single unconditional drop can't be right for both paths,
-- so the reclaimer used to leave it un-dropped (AX0911 leak → the "pull the conditional into tail
-- position" workaround that litters fff/lambda/pass). `normalize_mixed_cond_lets` now COPIES the
-- non-owned arms (`else s` → `else (strAppend s "")` / `axion_bignum_copy`) BEFORE borrow analysis,
-- so every arm is uniformly owned and `x` is reclaimed like any all-heap conditional temp.
--
-- Covers String (`pickStr`), Integer (`pickInt`), and the consumed-sub-expression form
-- `f (if …)` (`viaArg`, which lowers to the same `let tmp = if …`). Both branches of each are
-- exercised. Verify- and leak-clean on interp/dev/release.

pickStr :: Int -> String -> String
pickStr c s =
  let x = if c > 0 then strAppend "ab" "cd" else s in
  strAppend x "!"

pickInt :: Int -> Integer -> Integer
pickInt c n =
  let x = if c > 0 then fromInt 10 + fromInt 20 else n in
  x + fromInt 1

viaArg :: Int -> String -> String
viaArg c s = strAppend (if c > 0 then strAppend "x" "y" else s) "?"

main :: IO ()
main = do
  putStrLn (pickStr 1 "zz")
  putStrLn (pickStr 0 "zz")
  putStrLn (showInteger (pickInt 1 (fromInt 99)))
  putStrLn (showInteger (pickInt 0 (fromInt 99)))
  putStrLn (viaArg 1 "zz")
  putStrLn (viaArg 0 "zz")
