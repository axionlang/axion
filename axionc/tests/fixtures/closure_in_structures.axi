-- Closures stored in structures are reclaimed: a `Maybe`, a list, a tuple of closures frees each
-- closure it holds (key `…$Closure…` → `axion_closure_drop`, which runs the closure's own
-- destructor when it owns captures). They used to leak silently (the verifier could not see it).
--
-- Each structure owns the closures it frees:
--   * a lambda put into a structure owns COPIES of its heap captures (`mkJ`, `labels`);
--   * a closure the function does not own, or embeds twice (`store f = Just f`, `twice f = Cons f
--     (Cons f Nil)`, `both f = (f, f)`, a generic `dupL` at a closure type), is embedded as a COPY
--     (`axion_closure_copy`: the cell, plus the captures it owns) — otherwise two owners free one
--     cell (`firstTwice`/`firstOf` were native double frees during this change);
--   * a structure holding closures copies through the same copier (`keepOr`'s alias return).
-- A `%1` function-typed parameter is freed by its function, and a function returning a closure
-- gives its caller an owned one (`idG`, `pick`, `getF`).
-- Expected: 2 / 13 / 19 / 4 / 6 / 42 / 9 / 11 / 10 / 6 / 11 / 4 / 8 / 10 / 7 / 25
-- (leak-free under ASan + LSan).

call1 :: Maybe (Int -> Int) -> Int -> Int
call1 m x = case m of
  Just f -> f x
  Nothing -> 0

callAll :: List (Int -> Int) -> Int -> Int
callAll fs x = case fs of
  Nil -> 0
  Cons f r -> f x + callAll r x

applyAll :: List (Int -> Int) -> Int -> Int
applyAll fs x = case fs of
  Nil -> x
  Cons f r -> applyAll r (f x)

store :: (Int -> Int) -> Maybe (Int -> Int)
store f = Just f

mkJ :: Int -> Maybe (Int -> Int)
mkJ n = let s = show n in Just (\z -> strLen s + z)

pairUp :: Int -> (Int -> Int, Int)
pairUp n = (\z -> z + n, n)

adders :: List Int -> List (Int -> Int)
adders ns = case ns of
  Nil -> Nil
  Cons n r -> Cons (\z -> z + n) (adders r)

labels :: List String -> List (Int -> Int)
labels ss = case ss of
  Nil -> Nil
  Cons s r -> let t = strAppend s "!" in Cons (\z -> strLen t + z) (labels r)

keepOr :: Maybe (Int -> Int) -> Maybe (Int -> Int) -> Maybe (Int -> Int)
keepOr a b = case a of
  Just f -> a
  Nothing -> b

twice :: (Int -> Int) -> List (Int -> Int)
twice f = Cons f (Cons f Nil)

both :: (Int -> Int) -> (Int -> Int, Int -> Int)
both f = (f, f)

dupL :: a -> List a
dupL x = Cons x (Cons x Nil)

pairWith :: a -> b -> (a, b)
pairWith x y = (x, y)

idG :: a -> a
idG x = x

firstTwice :: List (Int -> Int) -> Int
firstTwice fs = case fs of
  Cons f _ -> callAll (twice f) 1
  Nil -> 0

firstStored :: List (Int -> Int) -> Int
firstStored fs = case fs of
  Cons f _ -> call1 (store f) 2
  Nil -> 0

firstOf :: List (Int -> Int) -> Int
firstOf fs = case fs of
  Cons f _ -> case both f of
    (g, h) -> g 1 + h 2
  Nil -> 0

getF :: Maybe (Int -> Int) -> (Int -> Int)
getF m = case m of
  Just f -> f
  Nothing -> \z -> z

pick :: Bool -> (Int -> Int) -> (Int -> Int) -> (Int -> Int)
pick b f g = if b then f else g

main :: IO ()
main = do
  putStrLn (show (call1 (Just (\z -> z + 1)) 1))
  let n = 5
  let m = store (\z -> z + n)
  putStrLn (show (call1 m 1 + call1 m 2))
  putStrLn (show (applyAll [\z -> z + 1, \z -> z * 2, \z -> z - 3] 10))
  putStrLn (show (call1 (mkJ 123) 1))
  case pairUp 3 of
    (f, k) -> putStrLn (show (f k))
  let fs = adders [1, 2, 3]
  putStrLn (show (callAll fs 10 + callAll fs 0))
  let ls = labels ["ab", "cde"]
  putStrLn (show (callAll ls 1))
  let s = show 4321
  let j = Just (\z -> strLen s + z)
  let kk = keepOr j Nothing
  putStrLn (show (call1 kk 1 + call1 j 2))
  let gs = [\z -> z + strLen s, \z -> z * 2]
  putStrLn (show (firstTwice gs))
  putStrLn (show (firstStored gs))
  putStrLn (show (firstOf gs))
  putStrLn (show (callAll (dupL (\z -> z + 1)) 1))
  case pairWith (\z -> z - 1) 9 of
    (g, k) -> putStrLn (show (g k))
  putStrLn (show ((idG (\z -> z * 5)) 2))
  let jm = Just (\z -> z + strLen (show 77))
  let h = getF jm
  putStrLn (show (h 1 + h 2))
  let a = \z -> z * 2
  let b = \z -> z * 3
  putStrLn (show (pick True a b 5 + pick False a b 5))
