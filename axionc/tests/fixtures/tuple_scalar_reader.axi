-- A function that returns a SCALAR component of a tuple only reads it, so it borrows the tuple.
--
-- It used to own the tuple whenever it returned any component directly, so `pick` — which hands
-- it a tuple living inside its own borrowed argument — was refused natively (AX0910: the callee
-- would free memory the caller still owns). A returned HEAP component still makes the function
-- an owner (the result points into the tuple): `keyOf` keeps that rule.
-- Expected: 9 / 14 / k7 / 3
-- (leak-free under ASan + LSan).

mkp :: Int -> (String, Int)
mkp n = ("k", n)

sndof :: (String, Int) -> Int
sndof t = case t of
  (a, b) -> b

build :: Int -> Maybe ((String, Int), List (String, Int))
build n = Just (mkp n, Cons (mkp (n + 1)) Nil)

pick :: Maybe ((String, Int), List (String, Int)) -> Int
pick m = case m of
  Just p -> case p of
    (h, rest) -> sndof h
  Nothing -> 0

twiceRead :: (String, Int) -> Int
twiceRead t = sndof t + sndof t

keyOf :: (String, Int) -> String
keyOf t = case t of
  (a, b) -> a

main :: IO ()
main = do
  putStrLn (show (pick (build 9)))
  putStrLn (show (twiceRead (mkp 7)))
  putStrLn (strAppend (keyOf (mkp 7)) (show 7))
  putStrLn (show (length (map sndof [mkp 1, mkp 2, mkp 3])))
