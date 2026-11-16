-- `==` inside a function constrained by `Eq a` dispatches to the instance of the type it is
-- specialized at. It was left as the primitive compare (`==` is filed under the synthetic `Ord`,
-- so an `Eq a` scope did not count): natively a pointer compare of two cells, so `same (P 1 2)
-- (P 1 3)` was False although the user's instance says they are equal; the interpreter failed
-- with "operator '==' does not apply to record and record". Likewise a constrained function
-- specialized at `Integer` kept the Int operator (`==`, `+`) over two bignum pointers: `same 7 7`
-- was False and `dbl (fromInt 21)` crashed natively; both now use the `#I` operators.
-- A constrained function calling a generic OWNING function (`dropOne`, `delBy`) over its
-- constraint var now requests the owning clone at each specialized type (`dropOne$Int`), and a
-- class method used in a closure (`delBy eq`, `\p q -> p == q`) is left to the class
-- specialization instead of being lifted into one shared, unresolved function. `main` used to be
-- pruned as non-native.
-- Expected: 1 / 1 / 0 / 1 / 1 / 0 / 1 / 1 / 42 / [2, 3] / [1, 3] / [1, 2] / [2, 3]
-- (leak-free under ASan + LSan).

data P = P Int Int

instance Eq P where
  eq a b = case a of
    P x _ -> case b of
      P y _ -> x == y

same :: Eq a => a -> a -> Bool
same x y = x == y

count :: Eq a => a -> List a -> Int
count x ys = case ys of
  Nil -> 0
  Cons y rest -> (if x == y then 1 else 0) + count x rest

dbl :: Num a => a -> a
dbl x = x + x

dropOne :: a -> List a %1 -> List a
dropOne x ys = case ys of
  Nil -> Nil
  Cons y rest -> rest

firstOut :: Eq a => a -> List a %1 -> List a
firstOut x ys = if x == x then dropOne x ys else ys

delBy :: (a -> a -> Bool) -> a -> List a %1 -> List a
delBy f x ys = case ys of
  Nil -> Nil
  Cons y rest -> if f x y then rest else Cons y (delBy f x rest)

delE :: Eq a => a -> List a %1 -> List a
delE x ys = delBy eq x ys

delL :: Eq a => a -> List a %1 -> List a
delL x ys = delBy (\p q -> p == q) x ys

b2i :: Bool -> Int
b2i b = if b then 1 else 0

main :: IO ()
main = do
  putStrLn (show (b2i (P 1 2 == P 1 3)))
  putStrLn (show (b2i (same (P 1 2) (P 1 3))))
  putStrLn (show (b2i (same (P 1 2) (P 2 2))))
  putStrLn (show (b2i (same 4 4)))
  putStrLn (show (b2i (same 2.5 2.5)))
  putStrLn (show (b2i (same "ab" "ac")))
  putStrLn (show (b2i (same (fromInt 7) (fromInt 7))))
  putStrLn (show (count (P 1 0) [P 1 5, P 2 5, P 1 9] - 1))
  putStrLn (show (dbl (fromInt 21)))
  putStrLn (show (firstOut 3 [1, 2, 3]))
  putStrLn (show (delBy eq 2 [1, 2, 3]))
  putStrLn (show (delE 3 [1, 2, 3]))
  putStrLn (show (delL 1 [1, 2, 3]))
