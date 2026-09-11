-- Peel deconstruction (`uncons`) over a HEAP element type (String) — the list-argv / dispatch
-- shape (`case uncons args of Just (cmd, rest) -> …`). This was formerly rejected by AX0912: the
-- native backends miscompiled the moved-out tuple element to a use-after-free (the whole-tuple
-- deep-drop `str_drop`ed the head that had escaped the tuple). The case-lowering now reclaims a
-- moved-out heap tuple element soundly — a tail-ordered whole-tuple deep-drop when the head is
-- BORROWED, or an `axion_drop_tuple$…_skip_N` skip-destructor when it is MOVED OUT or a heap
-- sibling is DISCARDED — so it compiles and runs leak-free on both native backends.
--
-- Shapes exercised:
--   · firstOr  — head RETURNED as the heap result, tail (a heap List) DISCARDED (skip-destructor
--                frees the tail + shell, keeps the returned head).
--   · rebuildLen — head AND tail MOVED OUT into a fresh `Cons` (both slots skipped → shell free).
-- interp == cranelift == llvm; ASan + LSan clean.

firstOr :: List String -> String
firstOr xs = case uncons xs of
  Nothing -> "none"
  Just p -> case p of
    (x, _) -> x

rebuildLen :: List String -> Int
rebuildLen xs = case uncons xs of
  Nothing -> 0
  Just p -> case p of
    (h, t) -> length (Cons h t)

main :: IO ()
main = do
  putStrLn (firstOr (Cons "a" (Cons "b" Nil)))
  putStrLn (firstOr Nil)
  putStrLn (showInt (rebuildLen (Cons "x" (Cons "y" (Cons "z" Nil)))))
