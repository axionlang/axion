-- Regression: a `where`-local that CONSUMES a heap parameter must reclaim it.
-- `ulBal`/`ulPairs`/`ulTag` are balanced-`unlines` helpers that destructure and
-- rebuild `List String`, with `ulBal` returning a `String`. Before the fix, a
-- heap-consuming `where`-local was NOT marked owning its params (Auto-Drop is
-- gated on a written signature, and these locals have none) → it leaked every
-- heap value it consumed, while `--emit verify` reported "balanced" (a leak
-- FALSE-NEGATIVE). The String result additionally fooled a result-type heuristic
-- into classifying `ulBal` as a borrower. Now each local owns its inferred heap
-- params exactly like its leak-free top-level twin; LSan must be clean.
ulines :: List String -> String
ulines xs = ulBal (ulTag xs)
  where
    ulTag ys = case ys of
      Nil -> Nil
      Cons y yss -> Cons (strAppend y "\n") (ulTag yss)
    ulPairs ys = case ys of
      Nil -> Nil
      Cons a r -> case r of
        Nil -> Cons a Nil
        Cons b m -> Cons (strAppend a b) (ulPairs m)
    ulBal ys = case ys of
      Nil -> ""
      Cons a r -> case r of
        Nil -> a
        Cons b m -> ulBal (Cons (strAppend a b) (ulPairs m))
main :: IO ()
main = putStr (ulines (sort (Cons "dd" (Cons "cc" (Cons "bb" (Cons "aa" Nil))))))
