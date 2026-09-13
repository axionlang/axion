-- Regression for the AX0911 tail-borrow / conditional-escape String leak (docs core.rs, the `</>`
-- residual). An owned `String` param returned BARE on one control path (→ owned) but only BORROWED
-- on another — at a tail `ret <op v>` where the op reads `v` and returns a FRESH string — leaked
-- the owned param on the borrowed path: `reclaim_cond_escape` never carried String params (heap_ty
-- excludes String), and the tail-`ret op` synthesis didn't treat a user `CallDirect` as fresh. Now
-- owned String params are reclaimed uniformly (`axion_str_drop`, which skips literals), and a tail
-- op that borrows one and returns a non-aliasing result (a fresh builtin OR a call not in the
-- interprocedural alias summary) drops it after the return. All three arms below are leak-free.
wrap :: String -> String
wrap s = strAppend "<" (strAppend s ">")

joinP :: String -> String -> String
joinP a b =
  if strLen a == 0 then b                 -- b escapes bare (owned)
  else if strLen b == 0 then wrap a       -- tail user-call borrows a, fresh result → drop a
  else strAppend a b                      -- tail builtin borrows a,b, fresh result → drop both

main :: IO ()
main = do
  putStrLn (joinP "" (strAppend "h" "1"))
  putStrLn (joinP (strAppend "p" "2") "")
  putStrLn (joinP (strAppend "x" "3") (strAppend "y" "4"))
