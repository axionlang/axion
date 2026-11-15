-- A by-copy record update (`r { name = n }`) shares the unchanged heap fields with its base.
-- Within one function the skip-destructors decide which side frees them, but when the base is
-- not owned there (a parameter, a record bound by a pattern) and the new record is returned, the
-- caller freed those fields twice: once with the base, once with the new record. The new record
-- now gets its own copies of the shared heap fields. Found by the `gen_ownership` fuzzer.
-- Same result on every backend, ASan + LSan clean.
data Rec = Rec { name :: String, items :: List String, note :: String }

recLen :: Rec -> Int
recLen r = strLen (name r) + length (items r) + strLen (note r)

rename :: Rec -> String -> Rec
rename r n = r { name = n }

-- a record bound by a pattern, updated and returned
renameFirst :: Maybe Rec -> Rec
renameFirst m = case m of
  Just r -> r { note = "first" }
  Nothing -> Rec { name = "", items = Nil, note = "" }

main :: Int
main =
  let v0 = Rec { name = showInt 917, items = Cons "s0" (Cons (strAppend "a" "b") Nil), note = showInt 4 } in
  let m = Just (Rec { name = "m", items = Cons (showInt 7) Nil, note = "" }) in
  recLen (rename v0 "") + recLen (rename (rename v0 "x") "yz") + recLen v0 + recLen (renameFirst m)
