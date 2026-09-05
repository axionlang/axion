-- Auto-Drop (§): a let-bound fresh heap value (here a String from getEnv) that
-- CONDITIONALLY escapes — returned in one branch, dropped in the other — is reclaimed
-- branch-sensitively (reclaim_cond_escape seeds such let-bound producers). Both arms
-- are exercised; runs clean and agrees on every backend. Harness sets COND_VAR=hello.
pick :: Int -> String
pick n =
  let s = getEnv "COND_VAR" in
  if strLen s > n then s else "short"

main :: IO ()
main = do
  putStrLn (pick 1000000)  -- len(hello)=5 > 1000000 is false → "short" (drop s)
  putStrLn (pick 0)        -- 5 > 0 → s escapes ("hello")
