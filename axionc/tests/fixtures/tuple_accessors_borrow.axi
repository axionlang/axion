-- `fst x` / `snd x` on a variable only read the tuple: `x` stays usable afterwards
-- (the prelude functions own their argument; a saturated call on a variable is an inline case).

-- a predicate reading the pair, the list used again after
big :: List (String, Int) -> List (String, Int)
big ps = filter (\p -> snd p > 1) ps

-- both parts read, one of them twice
again :: (String, Int) -> String
again p = fst p ++ ":" ++ showInt (snd p) ++ fst p

-- read, then stored whole on one branch
keepIf :: (String, Int) -> List (String, Int)
keepIf y = if snd y > 0 then Cons y Nil else Nil

-- a part stored in a new list while the input list is the caller's
firsts :: List (String, Int) -> List String
firsts xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons (fst y) (firsts ys)

-- a temporary argument still goes to the prelude function, which frees it
pairK :: Int -> (String, Int)
pairK n = (showInt n, n)

-- a part moved out of a temporary tuple, bound and used: freed after its use
tempPart :: Int -> String
tempPart n =
  let s = (case pairK n of (a, _) -> a)
  in s ++ "!"

-- a function with its own `fst` is left alone
local :: (Int, Int) -> Int
local q =
  let fst p = (case p of (a, b) -> a * 10 + b)
  in fst q

catL :: List String -> String
catL xs = case xs of
  Nil -> "."
  Cons a rest -> a ++ "," ++ catL rest

mkPs :: Int -> List (String, Int)
mkPs k = [("a" ++ "", k + 1), ("bb" ++ "", k + 2), ("ccc" ++ "", k + 3)]

main :: IO ()
main = do
  putStrLn (catL (map fst (big (mkPs 0))))
  let ps = mkPs 0
  putStrLn (catL (map (\p -> fst p ++ "!") ps))
  putStrLn (showInt (length (firsts ps) + length ps))
  putStrLn (again ("x" ++ "y", 4))
  putStrLn (showInt (length (keepIf ("q" ++ "", 2)) + length (keepIf ("r" ++ "", 0))))
  putStrLn (fst (pairK 7) ++ snd ("u", "v" ++ "w"))
  putStrLn (showInt (local (4, 2)))
  putStrLn (tempPart 9)
