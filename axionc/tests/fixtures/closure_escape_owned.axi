-- A closure RETURNED from the function that makes it owns copies of its heap captures.
--
-- `mkS n = let s = show n in \z -> strLen s + z`: the closure outlives `mkS`. It used to keep
-- `s` alive by escaping with it, and nothing ever freed `s` (refused natively, AX0911). Now the
-- closure captures a COPY of `s` (the frame frees its own `s`), the copy moves into the cell
-- `{fn_ptr, dtor, captures…}`, and the caller, which owns the returned closure (key `Closure`),
-- frees it after its last call through `axion_closure_drop` — which runs the closure's generated
-- destructor `axion_drop_clo$lam…`, freeing the copy. Covers String, List, Integer, record and
-- tuple captures, a factory chain (`wrap`), closures made in branches (`pick`), a partially
-- applied function (`mkL`, whose list a lambda builds: its destructor used to be missing) and a
-- non-capturing returned closure (`adder`, whose cell the caller used to leak).
-- Expected: 13 / 16 / 42 / 8 / 79 / 2 / 12 / 7 / 2
-- (leak-free under ASan + LSan).

data P = P String Int

nameOf :: P -> String
nameOf p = case p of
  P s _ -> s

sumL :: List Int -> Int
sumL xs = case xs of
  Nil -> 0
  Cons y r -> y + sumL r

mkS :: Int -> (Int -> Int)
mkS n = let s = show n in \z -> strLen s + z

mkL :: List Int -> (Int -> Int)
mkL xs = \z -> sumL xs + z

mkI :: Integer -> (Integer -> Integer)
mkI b = \z -> b + z

mkP :: String -> Int -> (Int -> Int)
mkP nm k = let p = P nm k in \z -> strLen (nameOf p) + z + k

mkT :: Int -> (Int -> Int)
mkT n = let t = (show n, n) in \z -> case t of
  (a, b) -> strLen a + b + z

wrap :: Int -> (Int -> Int)
wrap n = mkS (n * 10)

pick :: Bool -> String -> (Int -> Int)
pick b s = if b then (\z -> strLen s + z) else (\z -> z * 2)

adder :: Int -> (Int -> Int)
adder n = \z -> z + n

apply2 :: (Int -> Int) -> Int -> Int
apply2 f x = f (f x)

main :: IO ()
main = do
  let f = mkS 12345
  putStrLn (show (f 1 + f 2))
  let g = mkL [1, 2, 3]
  putStrLn (show (g 10))
  putStrLn (showInteger (mkI (fromInt 40) (fromInt 2)))
  putStrLn (show (mkP "abc" 4 1))
  putStrLn (show (mkT 77 0))
  putStrLn (show (wrap 5 0))
  putStrLn (show (pick True "hey" 1 + pick False "no" 4))
  putStrLn (show (apply2 (adder 3) 1))
  putStrLn (show (apply2 (mkS 9) 0))
