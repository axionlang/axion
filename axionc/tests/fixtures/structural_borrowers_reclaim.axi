-- The structural (non-closure) list borrowers — `take` / `drop` / `head` / `last` — over a
-- HEAP element type (String). These extract or keep input elements into their result; while
-- their list param was BORROWED they aliased a shared element into the output, so the native
-- backend double-freed it (`head`/`last`/`take`) or leaked the discarded prefix (`drop`) over a
-- heap element — the AX0912 alias-borrower class. Marking the list param `%1` (consume) turns
-- each kept element into a genuine MOVE and each discarded one into a free, reclaimed by the
-- ordinary skip / deep-drop machinery: no alias, no double-free, no leak. interp == cranelift
-- == llvm; ASan + LSan clean (see scripts/sanitize.sh). Closure-based borrowers (`filter`/
-- `takeWhile`) reach soundness a different way — higher-order specialization — see
-- filter_heap_reject.axi.
firstOf :: List String -> String
firstOf xs = case head xs of
  Nothing -> "none"
  Just x -> x

lastOf :: List String -> String
lastOf xs = case last xs of
  Nothing -> "none"
  Just x -> x

main :: IO ()
main = do
  putStrLn (firstOf (Cons "a" (Cons "b" (Cons "c" Nil))))
  putStrLn (lastOf (Cons "a" (Cons "b" (Cons "c" Nil))))
  putStrLn (showInt (length (take 2 (Cons "a" (Cons "b" (Cons "c" Nil))))))
  putStrLn (showInt (length (drop 2 (Cons "a" (Cons "b" (Cons "c" Nil))))))
