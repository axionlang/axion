-- Regression: the drop-verifier must CATCH the borrowed-container-element double-free at compile
-- time (the `axpass show` fzf-path bug, reverted in 16ceefb). `work` BORROWS its `List String`
-- (the caller deep-drops it) and passes each element `e` to `consume`; if a drop-inserting pass
-- makes `consume` FREE its String param (a case-extracted element of the borrowed list), the
-- owner's later deep-drop double-frees `e`. Element heap-ness is poly-erased inside generic `work`,
-- so the verifier resolves it from the CALLEE genuinely dropping a value there (`frees_heap`).
--
-- Normal build: no String reclaim → `consume` borrows → leak-free, ASan/LSan clean, verify clean.
-- With AXION_STRING_RECLAIM=1 (the reverted unsound reclaim, hook-gated): `consume` frees `e` →
-- the verifier reports DropOfAlias in `work` and AX0910 aborts (see tests/verify.rs).
consume :: String -> String
consume name = if strLen name == 0 then name else strAppend "x" "y"

work :: List String -> String
work xs = case xs of
  Nil -> ""
  Cons e rest -> strAppend (consume e) (work rest)

mk :: Int -> List String
mk n = if n == 0 then Nil else Cons (strAppend "e" (showInt n)) (mk (n - 1))

main :: IO ()
main = putStrLn (work (mk 3))
