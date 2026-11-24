-- Clause heads with constructor, tuple, literal and Bool patterns (nested too), tried in order:
-- each clause's head is tested before it is taken apart, and a call that no clause matches fails
-- at run time (natively as in the interpreter). Also a `case` on a Bool, whose `True`/`False`
-- arms are the integers 1/0 natively.
data Lst = LNil | LCons Int Lst
data Shape = Circle Int | Rect Int Int | Dot

zipLen :: Lst -> Lst -> Int
zipLen LNil _ = 0
zipLen _ LNil = 0
zipLen (LCons _ xs) (LCons _ ys) = 1 + zipLen xs ys

-- nested constructor patterns, most specific first
second :: Lst -> Int
second (LCons _ (LCons y _)) = y
second (LCons x LNil) = 0 - x
second LNil = 0

sizeOf :: Shape -> Shape -> Int
sizeOf (Rect w h) _ = w * h
sizeOf _ (Circle r) = r
sizeOf _ _ = 1

-- a literal and a constructor in one head
pick :: Int -> Maybe Int -> Int
pick 0 _ = 100
pick _ Nothing = 200
pick n (Just k) = n + k

-- tuples, nested
swapSum :: (Int, (Int, Int)) -> Int
swapSum (a, (b, c)) = a * 100 + b * 10 + c

-- Bool heads
both :: Bool -> Bool -> Int
both True True = 3
both True False = 2
both False True = 1
both False False = 0

-- a Bool case, both orders
yes :: Bool -> Int
yes b = case b of
  False -> 0
  True -> 1

flags :: (Bool, Int) -> Int
flags p = case p of
  (True, n) -> n
  (False, n) -> 0 - n

-- guards inside a constructor clause
classify :: Shape -> String
classify (Circle r)
  | r > 10 = "big circle"
  | otherwise = "circle"
classify (Rect w h)
  | w == h = "square"
  | otherwise = "rect"
classify Dot = "dot"

-- a where-local with clause heads
total :: Lst -> Int
total l = go l 0
  where
    go LNil acc = acc
    go (LCons x rest) acc = go rest (acc + x)

-- a partial function, only called where it matches
headOr :: Lst -> Int
headOr (LCons x _) = x

main :: IO ()
main = do
  let l3 = LCons 1 (LCons 2 (LCons 3 LNil))
  putStrLn (showInt (zipLen l3 (LCons 9 (LCons 8 LNil))))
  putStrLn (showInt (second l3 + second (LCons 5 LNil) + second LNil))
  putStrLn (showInt (sizeOf (Rect 2 3) Dot + sizeOf Dot (Circle 5) + sizeOf Dot Dot))
  putStrLn (showInt (pick 0 Nothing + pick 4 Nothing + pick 4 (Just 6)))
  putStrLn (showInt (swapSum (1, (2, 3))))
  putStrLn (showInt (both True False * 1000 + both False True * 100 + both True True * 10 + both False False))
  putStrLn (showInt (yes False + yes True * 10 + flags (True, 7) + flags (False, 2)))
  putStrLn (classify (Circle 20) ++ "," ++ classify (Circle 2) ++ "," ++ classify (Rect 3 3) ++ "," ++ classify (Rect 1 2) ++ "," ++ classify Dot)
  putStrLn (showInt (total l3 + headOr l3))
