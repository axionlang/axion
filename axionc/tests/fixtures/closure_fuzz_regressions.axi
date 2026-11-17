-- Closure bugs found by the closure-values fuzz generator (scripts/fuzz.py gen_closure_values):
--   * `pick b f g = if b then f else g` returned one of its ARGUMENTS while its caller owned the
--     result (a function returning a closure gives its caller an owned one): the caller and the
--     argument's owner both freed one cell — a use after free printed a pointer, or a double
--     free. Such a parameter is now returned as a copy.
--   * `pick True (mkSL 8) (mkSL 0) 1` (over-applying a closure-returning function whose closure
--     arguments are calls) printed a pointer: the hoisting of a complete call in a closure slot
--     split the application spine. (The pre-series compiler printed a pointer here too.)
--   * `useBoth (getF (store c))`: specializing `useBoth` treated the COMPLETE call `getF m` as a
--     partial application and re-ran it at each use — a false AX0001 on the compiler's own
--     `_cap0` (also in the pre-series compiler). The call is now bound once (`satclo`).
-- Expected: 2 / 12 / 2 / 27 / 5 / 4 / 23
-- (leak-free under ASan + LSan).

mkSL :: Int -> (Int -> Int)
mkSL n = let s = show n in \z -> strLen s + z

mkS :: String -> (Int -> Int)
mkS s = \z -> strLen s + z

mkT :: String -> Int -> (Int -> Int)
mkT nm k = let t = (nm, k) in \z -> case t of
  (a, b) -> strLen a + b + z

pick :: Bool -> (Int -> Int) -> (Int -> Int) -> (Int -> Int)
pick b f g = if b then f else g

store :: (Int -> Int) -> Maybe (Int -> Int)
store f = Just f

getF :: Maybe (Int -> Int) -> (Int -> Int)
getF m = case m of
  Just f -> f
  Nothing -> \z -> z

both :: (Int -> Int) -> (Int -> Int, Int -> Int)
both f = (f, f)

useBoth :: (Int -> Int) -> Int
useBoth f = case both f of
  (g, h) -> g 1 + h 2

twice :: (Int -> Int) -> List (Int -> Int)
twice f = Cons f (Cons f Nil)

callAll :: List (Int -> Int) -> Int -> Int
callAll fs x = case fs of
  Nil -> 0
  Cons f r -> f x + callAll r x

main :: IO ()
main = do
  putStrLn (show ((pick True (mkSL 8) (mkSL 0)) 1))
  putStrLn (show ((pick False (mkSL 0) (\z -> z * 2)) 6))
  putStrLn (show (pick True (mkSL 8) (mkSL 0) 1))
  putStrLn (show (useBoth (getF (store (mkT (show 381) 9)))))
  putStrLn (show (useBoth (getF (store (\z -> z + 1)))))
  putStrLn (show (callAll (twice (getF (store (mkS (show 3))))) 1))
  let f2 = pick True (mkS "bc") (\z -> z * 2)
  putStrLn (show (f2 6 + f2 7 + callAll [f2, f2] 1))
