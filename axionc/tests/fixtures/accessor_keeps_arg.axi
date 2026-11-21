-- A function that RETURNS a field of its list or tuple, at any depth (without storing one in a
-- new value), borrows its argument: the caller keeps using it afterwards. The field comes back as a borrow when every
-- path returns one (`firstOr` on a non-empty list is not that — its `Nil` path is a fresh
-- value, so the field is copied there), and nothing is freed twice.
data Box = Box Int

val :: Box -> Int
val b = case b of
  Box n -> n

firstOr :: List Box -> Box
firstOr xs = case xs of
  Nil -> Box 0
  Cons b _ -> b

secondOr :: Box -> List Box -> Box
secondOr d xs = case xs of
  Cons _ (Cons b _) -> b
  _ -> d

total :: List Box -> Int
total xs = case xs of
  Nil -> 0
  Cons b rest -> val b + total rest

fstS :: (String, Int) -> String
fstS t = case t of
  (a, _) -> a

pick :: (Maybe String, Int) -> String
pick x = case x of
  (Just s, 2) -> s
  (Just _, 0) -> "zero"
  _ -> "e"

label :: List String -> String
label ss = case ss of
  Nil -> "none"
  Cons s _ -> s

main :: IO ()
main = do
  let xs = Cons (Box 5) (Cons (Box 6) (Cons (Box 7) Nil))
  putStrLn (show (val (firstOr xs)))
  putStrLn (show (val (secondOr (Box 1) xs)))
  putStrLn (show (total xs))
  let ss = Cons "alpha" (Cons "beta" Nil)
  putStrLn (label ss)
  putStrLn (label ss ++ "!")
  putStrLn (show (length ss))
  let p = ("hi", 3)
  putStrLn (fstS p)
  putStrLn (fstS p ++ "?")
  let q = (Just "q", 2)
  putStrLn (pick q)
  putStrLn (pick q ++ pick (Just "w", 0))
