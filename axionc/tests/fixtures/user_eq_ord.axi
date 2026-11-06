-- user_eq_ord.axi — the comparison operators `== < > <=` over USER types, dispatched to the
-- `Eq`/`Ord` class methods (`eq$T`, and synthesized strict `lt$T`/`gt$T` over `le$T`). Covers a
-- `deriving (Eq, Ord)` type AND a hand-written instance. `<=` was already polymorphic over `le`.
data Color = Red | Green | Blue deriving (Eq, Ord)

data R = R Int Int
num :: R -> Int
num r = case r of R n d -> n
den :: R -> Int
den r = case r of R n d -> d
instance Eq R where
  eq a b = num a * den b == num b * den a
instance Ord R where
  le a b = num a * den b <= num b * den a

yn :: Bool -> String
yn b = if b then "T" else "F"

main :: IO ()
main = do
  putStrLn (yn (Red == Red))       -- T   (derived Eq)
  putStrLn (yn (Red == Green))     -- F
  putStrLn (yn (Red < Blue))       -- T   (derived Ord, strict <)
  putStrLn (yn (Blue > Red))       -- T
  putStrLn (yn (Green <= Green))   -- T
  putStrLn (yn (R 1 2 == R 2 4))   -- T   (hand Eq: 1/2 == 2/4)
  putStrLn (yn (R 1 3 < R 1 2))    -- T   (hand Ord: 1/3 < 1/2)
