-- Regression lock for the baseName/baseAfter aliasing double-free (fff bulk-rename + pass editTmp).
-- `baseName` over a name with NO '/' returns the whole string; before the fix `baseAfter` returned
-- the BORROWED argument itself, so here — where `y` is a borrowed element of a list the caller
-- (main) deep-drops and the `baseName y` result is dropped after `strAppend` reads it — dropping
-- that alias double-freed `y`. The fix makes `baseAfter` COPY on the no-'/' path so `baseName`
-- always yields an OWNED basename. verify + ASan + LSan clean; in sanitize LEAKFREE.
bnGo :: List String -> String
bnGo xs = case xs of
  Nil -> ""
  Cons y ys -> strAppend (baseName y) (strAppend "\n" (bnGo ys))

sample :: List String
sample = Cons (strAppend "foo" "") (Cons (strAppend "bar" "") (Cons (strAppend "baz" "") Nil))

main :: IO ()
main = putStr (bnGo sample)
