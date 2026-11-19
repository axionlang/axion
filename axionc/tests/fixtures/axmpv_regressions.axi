-- Shapes the axmpv flagship (examples/axmpv) hit — each refused natively, leaked, or answered
-- differently per backend before its fix. Same output on all three backends, ASan/LSan-clean.
data P = P { v :: Int, w :: Int, s :: String }
data Act = Act String (P -> P)

-- 1. `div`/`mod` applied as plain functions (`mod a b`) — the interpreter had "no instance of
--    method 'mod'", native refused the program. And `mod` truncates like C on every backend
--    (sign of the dividend): the interpreter was Euclidean, `--release` used `urem`.
divmod :: Int -> Int -> String
divmod a b = showInt (div a b) ++ "," ++ showInt (mod a b) ++ "," ++ showInt (a `mod` b)

-- 2. a NON-owned param passed to a closure call (`f p`): the call consumes its argument, so
--    the function took ownership silently and the caller's second use of `p` was refused
--    natively (AX0910 UseAfterFree). The param is now passed as a copy. `acts` is a
--    `List Act` of a plain data type with a closure field — its copier was missing.
acts :: List Act
acts = [Act "inc" (\p -> p { v = v p + 1 }), Act "dbl" (\p -> p { w = w p * 2 })]

run :: String -> P -> P
run name p = go acts name p

go :: List Act -> String -> P -> P
go xs name p = case xs of
  Nil -> p
  Cons a rest -> case a of
    Act n f -> if n == name then f p else go rest name p

-- 3. the result of a user function returned on one branch and dead on the other — left
--    unfreed on the dead branch (AX0910 Unbalanced).
look :: String -> String -> String
look km k = if strLen km > strLen k then substr 0 1 km else ""

optionOr :: String -> String -> String -> String
optionOr km name dflt =
  let v = look km (strAppend "=" name) in
  if strLen v > 0 then v else substr 0 (strLen dflt) dflt

-- 4. an owned record updated by copy on one branch and returned whole on the other: the old
--    block leaked on the update branch (the scalar field reads before it and the copied
--    `String` field both dropped it from the owned set).
check :: P -> P
check p = if (w p > 0) && (v p < 5) then p { v = 7 } else p

-- 5. a `let` whose arms are a by-copy update and the (borrowed) record itself: the record arm is
--    now copied (`axion_copy_P`), so the result is owned on every path — it leaked (AX0911).
bump :: P -> Int -> Int
bump p0 k = let p = if k == 0 then p0 { v = 9 } else p0 in v p + w p + strLen (s p)

-- 6. inside a closure, a by-copy update handed to another function (`\p -> tag (p { v = 0 })`):
--    the update shares `s` with `p`, and `p` dies first — it now leaves `s` to the update, which
--    `tag` still reads (it was freed with `p`: a use-after-free).
tag :: P -> P
tag p = p { w = 1 }

acts2 :: List Act
acts2 = [Act "zero" (\p -> tag (p { v = 0 }))]

-- 7. a fresh update moved on one branch and only read on the other: freed on that one (it leaked)
pick :: P -> Int -> Int
pick p k = let p1 = p { s = "new" } in if k > 0 then v (run "inc" p1) else w p1 + strLen (s p1)

showP :: P -> String
showP p = showInt (v p) ++ "/" ++ showInt (w p) ++ "/" ++ s p

main :: IO ()
main = do
  putStrLn (divmod 7 3 ++ " " ++ divmod (0 - 7) 3 ++ " " ++ divmod 7 (0 - 3) ++ " " ++ divmod (0 - 7) (0 - 3))
  let p = P { v = 1, w = 3, s = "x" }
  let q = run "inc" p
  putStrLn (showP (run "dbl" p) ++ " " ++ showP q ++ " " ++ showP (run "none" p))
  putStrLn (optionOr "abcdef" "x" "d" ++ optionOr "" "x" "d")
  putStrLn (showP (check (P { v = 1, w = 2, s = "y" })) ++ " " ++ showP (check (P { v = 9, w = 2, s = "z" })))
  putStrLn (showInt (bump (P { v = 1, w = 2, s = "q" }) 0) ++ " " ++ showInt (bump (P { v = 1, w = 2, s = "q" }) 1))
  putStrLn (showP (go acts2 "zero" (P { v = 5, w = 7, s = "kept" })) ++ " " ++ showInt (pick (P { v = 1, w = 3, s = "x" }) 1) ++ " " ++ showInt (pick (P { v = 1, w = 3, s = "x" }) 0))
