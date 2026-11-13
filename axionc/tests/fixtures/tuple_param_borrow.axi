-- A function that only READS the components of a tuple parameter borrows it, like one that
-- reads a `data` record: the caller keeps the tuple. Before, any tuple destructure took
-- ownership, so `filter big` over a tuple list freed every kept element (verifier AX0910),
-- calling a reader twice was AX0001, and a lambda over tuples was AX0912 on native builds.
-- A function whose heap component escapes (`fstS`) still takes ownership.
data J = JNum Int | JStr String

big :: (String, Int) -> Bool
big t = case t of
  (a, b) -> b > 1

bigH :: (String, Int) -> Bool
bigH (a, b) = b > 1

lenK :: (String, Int) -> Int
lenK t = case t of
  (a, b) -> strLen a + b

sndG :: (a, Int) -> Int
sndG t = case t of
  (a, b) -> b

fstS :: (String, Int) -> String
fstS t = case t of
  (a, b) -> a

inner :: (String, (String, Int)) -> Int
inner t = case t of
  (a, p) -> case p of
    (c, n) -> strLen a + strLen c + n

isK :: String -> (String, J) -> Bool
isK k m = case m of
  (a, v) -> a == k

valOf :: (String, J) -> Int
valOf m = case m of
  (a, v) -> case v of
    JNum n -> n
    JStr s -> strLen s

pairs :: Int -> List (String, Int)
pairs n = [(show n, 1), (show (n + 1), 2), (show (n + 2), 3)]

count :: String -> List (String, Int) -> Int
count k xs = length (filter (\t -> case t of
  (a, b) -> a == k) xs)

main :: Int
main = length (filter big (pairs 10))
  + length (filter bigH (pairs 20))
  + length (filter (\t -> case t of
      (a, b) -> b > 2) (pairs 30))
  + length (filter (\(a, b) -> b > 1) (pairs 40))
  + count "51" (pairs 50)
  + (if any big (pairs 60) then length (takeWhile big (pairs 70)) else 0)
  + lenK (show 1234, 5) + lenK (show 1234, 5)
  + sndG (show 9, 3) + sndG (show 9, 3)
  + strLen (fstS (show 123, 4))
  + inner (show 1, (show 22, 3))
  + foldl (\acc m -> acc + valOf m) 0 (filter (isK "b") [("a", JNum 1), ("b", JStr (show 123)), ("b", JNum 5)])
