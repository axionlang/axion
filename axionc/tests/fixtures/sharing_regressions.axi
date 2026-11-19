-- Reclamation gaps found by the fuzzer's `sharing` generator (scripts/fuzz.py gen_sharing): safe
-- code the native backends refused (AX0910/AX0911) or freed twice. Same output on every backend,
-- ASan/LSan-clean.
data P = P { n :: Int, s :: String, xs :: List Int, t :: String }
data Act = Act String (P -> P)

sumL :: List Int -> Int
sumL l = case l of
  Nil -> 0
  Cons y r -> y + sumL r

m :: P -> Int
m p = n p + strLen (s p) + sumL (xs p) + strLen (t p)

mk :: Int -> P
mk k = P { n = k, s = "s" ++ showInt k, xs = [k, k + 1], t = "t" }

setS :: P -> P
setS p = p { s = "z" ++ s p }

bumpIf :: P -> P
bumpIf p = if n p > 3 then p { n = 0 } else p

-- 1. an update whose new field is built from the field it replaces, inside a closure
--    (`p { xs = Cons 5 (xs p) }`): the old field moves into the new list (false leak)
acts :: List Act
acts = [Act "d" (\p -> p { xs = Cons 5 (xs p) })]

run :: String -> P -> P
run name p = goRun acts name p

goRun :: List Act -> String -> P -> P
goRun as2 name p = case as2 of
  Nil -> p
  Cons a rest -> case a of
    Act nm f -> if nm == name then f p else goRun rest name p

-- 2. a field of a temporary record, kept on one path only (it leaked on the other)
keepS :: P -> Int -> Int
keepS p0 k = strLen (let v = s (setS p0) in if k > 0 then v else "")

-- 3. chains of updates sharing different fields, used in every order
chainA :: Int -> Int
chainA k = let b0 = mk k in let b1 = b0 { xs = Cons 1 Nil, t = "" } in let b2 = b1 { s = "w" } in sumL (xs b2) + m b1

chainB :: Int -> Int
chainB k = let b0 = mk k in let b1 = b0 { s = "w", xs = Nil } in let b2 = b1 { t = "t2" } in m b0 + sumL (xs b2)

chainC :: Int -> Int
chainC k = let b0 = mk k in let b1 = b0 { xs = Cons 0 Nil } in let b2 = b1 { xs = Nil, s = "w" } in strLen (s b1) + m b0 + sumL (xs b2)

chainD :: Int -> Int
chainD k = let b0 = mk k in let b1 = b0 { s = "w", n = 4 } in let b2 = b1 { t = "t2", xs = [1, 2] } in strLen (s b1) + m b1 + sumL (xs b2)

-- 4. a conditional temp updated on one branch and the update moved into a call
condUpd :: P -> Int -> Int
condUpd p0 k = let p = if k > 5 then p0 { s = "w" } else p0 in if n p > 6 then m (bumpIf (p { s = "x" ++ "y" })) else m p

-- 5. an update of an update moved into a call: the middle record shares one field with each
escapes :: Int -> Int
escapes k = m ((((mk k) { t = "t2", xs = [1, 2] }) { s = "w", t = "" }))

main :: IO ()
main = do
  putStrLn (showInt (m (run "d" (mk 2))) ++ " " ++ showInt (keepS (mk 3) 1) ++ " " ++ showInt (keepS (mk 3) 0))
  putStrLn (showInt (chainA 3) ++ " " ++ showInt (chainB 2) ++ " " ++ showInt (chainC 4) ++ " " ++ showInt (chainD 5))
  putStrLn (showInt (condUpd (mk 9) 7) ++ " " ++ showInt (condUpd (mk 2) 1) ++ " " ++ showInt (escapes 5))
