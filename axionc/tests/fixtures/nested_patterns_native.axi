-- Nested patterns compile natively: the compiler turns them into nested single-level cases (the
-- code you would write by hand). First match still wins when rows overlap across constructors;
-- catch-all rows reach every group; heap payloads (String, lists, records) are freed exactly once
-- whether they are returned, combined, stored or dropped.
data Shape = Circle Int | Rect Int Int
data Named = Named { label :: String, shape :: Shape }

area :: Maybe Shape -> Int
area m = case m of
  Just (Circle r) -> 3 * r * r
  Just (Rect w h) -> w * h
  Nothing -> 0

-- overlapping rows: the specific row first, then a catch-all for the same constructor
classify :: List Int -> String
classify xs = case xs of
  Cons 0 (Cons 0 _) -> "two zeros"
  Cons 0 _ -> "zero first"
  Cons _ (Cons 0 _) -> "zero second"
  Cons a Nil -> "one " ++ showInt a
  ys -> "other " ++ showInt (length ys)

-- String payloads two levels down: returned, combined, or dropped
names :: List String -> String
names xs = case xs of
  Cons a (Cons b _) -> a ++ "+" ++ b
  Cons a Nil -> a
  Nil -> "none"

-- tuples in tuples and in constructors
deep :: Maybe ((Int, Int), String) -> String
deep m = case m of
  Just ((0, y), s) -> s ++ showInt y
  Just ((x, _), s) -> showInt x ++ s
  Nothing -> "-"

-- a record under a constructor; its String field kept, the record freed
labelOf :: Maybe Named -> String
labelOf m = case m of
  Just (Named l (Circle _)) -> "circle " ++ l
  Just (Named l _) -> l
  Nothing -> "?"

-- the catch-all variable is the scrutinee itself
firstOr :: List String -> String
firstOr xs = case xs of
  Cons (s) Nil -> s
  other -> showInt (length other)

-- literal sub-patterns at two depths
lits :: Maybe (Maybe Int) -> Int
lits m = case m of
  Just (Just 0) -> 100
  Just (Just n) -> n
  Just Nothing -> 0 - 1
  Nothing -> 0 - 2

main :: IO ()
main = do
  putStrLn (showInt (area (Just (Rect 3 4)) + area (Just (Circle 2)) + area Nothing))
  putStrLn (classify (Cons 0 (Cons 0 Nil)))
  putStrLn (classify (Cons 0 (Cons 5 Nil)))
  putStrLn (classify (Cons 7 (Cons 0 Nil)))
  putStrLn (classify (Cons 9 Nil))
  putStrLn (classify (Cons 1 (Cons 2 (Cons 3 Nil))))
  putStrLn (classify Nil)
  putStrLn (names (Cons "ab" (Cons "cd" (Cons "ef" Nil))))
  putStrLn (names (Cons "solo" Nil))
  putStrLn (names Nil)
  putStrLn (deep (Just ((0, 5), "y=")))
  putStrLn (deep (Just ((4, 5), "x")))
  putStrLn (deep Nothing)
  putStrLn (labelOf (Just (Named "sun" (Circle 3))))
  putStrLn (labelOf (Just (Named "box" (Rect 1 2))))
  putStrLn (labelOf Nothing)
  putStrLn (firstOr (Cons "only" Nil))
  putStrLn (firstOr (Cons "a" (Cons "b" Nil)))
  putStrLn (showInt (lits (Just (Just 0)) + lits (Just (Just 7)) + lits (Just Nothing) + lits Nothing))
