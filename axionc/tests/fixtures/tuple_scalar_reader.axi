-- A function that returns a SCALAR component of a tuple only reads it, so it borrows the tuple.
--
-- It used to own the tuple whenever it returned any component directly, so `pick` — which hands
-- it a tuple living inside its own borrowed argument — was refused natively (AX0910: the callee
-- would free memory the caller still owns). A returned HEAP component still makes the function
-- an owner (the result points into the tuple): `keyOf` keeps that rule.
--
-- The verifier's own summary also has to know the returned field is a scalar: it used to see
-- `sndof`'s result as a pointer into the tuple, so `show (useOwned (mkb 8))` — the tuple freed
-- after the call, the Int read later — was refused as a use-after-free (fuzz seeds 95–97).
-- Expected: 9 / 14 / k7 / 3 / 8 / 5

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

mkb :: Int -> (Integer, Int)
mkb n = (fromInt n, n)

bsnd :: (Integer, Int) -> Int
bsnd t = case t of
  (a, b) -> b

useOwned :: (Integer, Int) -> Int
useOwned t = bsnd t

keyOf :: (String, Int) -> String
keyOf t = case t of
  (a, b) -> a

main :: IO ()
main = do
  putStrLn (show (pick (build 9)))
  putStrLn (show (twiceRead (mkp 7)))
  putStrLn (strAppend (keyOf (mkp 7)) (show 7))
  putStrLn (show (length (map sndof [mkp 1, mkp 2, mkp 3])))
  putStrLn (show (useOwned (mkb 8)))
  putStrLn (show (sndof (mkp 5)))
