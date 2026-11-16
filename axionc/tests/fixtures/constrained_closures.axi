-- Closures inside constrained functions are specialized per type, like the functions themselves.
--
-- A lambda handed to a higher-order function inside `Eq a => …` (or `Ord`/`Num`) is lifted to a
-- CONSTRAINED top-level function, captures first (`countBy (\y -> y == x) xs` →
-- `countBy (hoflamc<N> x) xs`), and the higher-order clone over a constrained closure inherits
-- its constraint. The class specialization then clones both per type, so:
--   * `==` in the closure dispatches to the instance (`eq$P`, the bignum compare at Integer);
--     `delBy myEq` used to compare pointers at `P` — a wrong answer (2 instead of 1);
--   * a heap element the closure call hands over is owned at its concrete type — left inline,
--     the lambda was lowered from its generic types in every clone and leaked each element
--     (`countAll`), or was refused natively (`delE`, AX0910).
-- Expected: 1 / 1 / 2 / 2 / 1 / 2 / 1 / 2 / 2 / 12 / 10 / 2
-- (leak-free under ASan + LSan).

data P = P Int Int

instance Eq P where
  eq a b = case a of
    P x _ -> case b of
      P y _ -> x == y

delBy :: (a -> a -> Bool) -> a -> List a %1 -> List a
delBy f x ys = case ys of
  Nil -> Nil
  Cons y rest -> if f x y then rest else Cons y (delBy f x rest)

countBy :: (a -> Bool) -> List a -> Int
countBy p xs = case xs of
  Nil -> 0
  Cons y r -> (if p y then 1 else 0) + countBy p r

mapL :: (a -> b) -> List a -> List b
mapL f xs = case xs of
  Nil -> Nil
  Cons y r -> Cons (f y) (mapL f r)

lenL :: List a -> Int
lenL xs = case xs of
  Nil -> 0
  Cons _ r -> 1 + lenL r

sumI :: List Int -> Int
sumI xs = case xs of
  Nil -> 0
  Cons y r -> y + sumI r

sumBig :: List Integer -> Integer
sumBig xs = case xs of
  Nil -> fromInt 0
  Cons y r -> y + sumBig r

-- a lambda using the class method
delE :: Eq a => a -> List a %1 -> List a
delE x ys = delBy (\p q -> p == q) x ys

-- a named constrained closure
myEq :: Eq a => a -> a -> Bool
myEq p q = p == q

delN :: Eq a => a -> List a %1 -> List a
delN x ys = delBy myEq x ys

-- a capturing lambda
countEq :: Eq a => a -> List a -> Int
countEq x xs = countBy (\y -> y == x) xs

-- a lambda that uses no method, over a heap element
countAll :: Eq a => a -> List a -> Int
countAll x xs = countBy (\y -> True) xs + (if x == x then 0 else 1)

zipLt :: Ord a => List a -> List a -> List Bool
zipLt xs ys = case xs of
  Nil -> Nil
  Cons a r -> case ys of
    Nil -> Nil
    Cons b s -> Cons (a < b) (zipLt r s)

smaller :: Ord a => List a -> List a -> Int
smaller xs ys = countBy (\b -> b) (zipLt xs ys)

dbls :: Num a => List a -> List a
dbls xs = mapL (\v -> v + v) xs

main :: IO ()
main = do
  putStrLn (show (lenL (delE (P 1 0) [P 1 5, P 2 5])))
  putStrLn (show (lenL (delN (P 1 0) [P 1 5, P 2 5])))
  putStrLn (show (lenL (delE (fromInt 7) [fromInt 3, fromInt 7, fromInt 7])))
  putStrLn (show (lenL (delN "b" ["a", "b", "c"])))
  putStrLn (show (lenL (delE 2.5 [2.5, 1.0])))
  putStrLn (show (countEq (P 2 9) [P 1 5, P 2 5, P 2 1]))
  putStrLn (show (countEq (fromInt 4) [fromInt 4, fromInt 5]))
  putStrLn (show (countAll (P 2 9) [P 1 5, P 2 5]))
  putStrLn (show (smaller [1, 5, 3] [2, 4, 4]))
  putStrLn (show (sumI (dbls [1, 2, 3])))
  putStrLn (showInteger (sumBig (dbls [fromInt 5])))
  putStrLn (show (countEq "x" ["x", "y", "x"]))
