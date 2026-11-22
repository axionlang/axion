-- Totality (docs/totality.md): every function below is declared total and proven so —
-- counting loops (up to a bound, down to 0, through a where-local), structural recursion,
-- a lexicographic measure (Ackermann), mutual recursion, two shrinking lists, Strings scanned
-- up to their length, guarded divisions and array accesses, and prelude higher-order functions.
{-# TOTAL sumTo len2 fact countUp sumArr ack evenOdd isEven isOdd merge safeDiv clampGet #-}
{-# TOTAL skipSpaces countA viaPrelude firstOr samePoint #-}
data Lst = LNil | LCons Int Lst
data Point = Point Int Int deriving (Show, Eq)

sumTo :: Int -> Int
sumTo n = go 0 1
  where go acc i = if i >= n then acc + i else go (acc + i) (i + 1)

len2 :: Lst -> Int
len2 l = case l of
  LNil -> 0
  LCons _ xs -> 1 + len2 xs

fact :: Int -> Int
fact n = if n <= 0 then 1 else n * fact (n - 1)

countUp :: Int -> Int -> Int
countUp i n = if i < n then countUp (i + 1) n else i

sumArr :: Array Int -> Int -> Int -> Int
sumArr a i acc = if i >= 0 && i < lenArray a then sumArr a (i + 1) (acc + getArray a i) else acc

ack :: Int -> Int -> Int
ack m n
  | m <= 0 = n + 1
  | n <= 0 = ack (m - 1) 1
  | otherwise = ack (m - 1) (ack m (n - 1))

isEven :: Int -> Bool
isEven n = if n <= 0 then True else isOdd (n - 1)

isOdd :: Int -> Bool
isOdd n = if n <= 0 then False else isEven (n - 1)

evenOdd :: Int -> Int
evenOdd n = if isEven n then 1 else 0

-- how many steps a merge of two sorted lists takes: either list shrinks at each call
merge :: Lst -> Lst -> Int
merge l r = case l of
  LNil -> 0
  LCons x xs -> case r of
    LNil -> 0
    LCons y ys -> if x < y then 1 + merge xs r else 1 + merge l ys

safeDiv :: Int -> Int -> Int
safeDiv a b = if b == 0 then 0 else a `div` b

clampGet :: Array Int -> Int -> Int
clampGet a i = if i >= 0 && i < lenArray a then getArray a i else 0

skipSpaces :: String -> Int -> Int
skipSpaces s i = if i >= 0 && i < strLen s && charAt i s == 32 then skipSpaces s (i + 1) else i

countA :: String -> Int
countA s = go 0 0
  where go i acc = if i < strLen s then go (i + 1) (if charAt i s == 97 then acc + 1 else acc) else acc

viaPrelude :: List Int -> Int
viaPrelude xs = foldl (\acc x -> acc + x) 0 (map (\x -> x * 2) (filter (\x -> x > 1) xs))

firstOr :: Int -> List Int -> Int
firstOr d xs = case head xs of
  Just x -> x
  Nothing -> d

samePoint :: Point -> Point -> Bool
samePoint p q = p == q

main :: IO ()
main = do
  putStrLn (showInt (sumTo 10 + len2 (LCons 1 (LCons 2 LNil)) + fact 5 + countUp 0 3))
  putStrLn (showInt (sumArr (newArray 4 3) 0 0 + ack 2 2 + evenOdd 7 + merge (LCons 1 (LCons 4 LNil)) (LCons 2 LNil)))
  putStrLn (showInt (safeDiv 7 0 + safeDiv 7 2 + clampGet (newArray 2 5) 9))
  putStrLn (showInt (skipSpaces "   x" 0 + countA "banana" + viaPrelude [1, 2, 3] + firstOr 4 []))
  putStrLn (if samePoint (Point 1 2) (Point 1 2) then "same" else "different")
