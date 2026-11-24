-- Pattern coverage under totality (docs/totality.md): every function below is declared total, so
-- each of its matches must cover every value. Each accepted match emits a coverage certificate
-- (`axionc --emit cover-certs`) that metatheory/cover-trace.sh re-checks with Lean
-- (`AxionCover.lean`): nested constructors, tuples, a three-constructor type, literals with a
-- fallback, clauses over two arguments, and a lambda pattern.
{-# TOTAL firstTwo zipLen classify describe both sizeOf orElse pairSum #-}
data Lst = LNil | LCons Int Lst
data Shape = Circle Int | Rect Int Int | Dot

-- nested: the second element when there is one
firstTwo :: Lst -> Int
firstTwo l = case l of
  LCons _ (LCons y _) -> y
  LCons x LNil -> x
  LNil -> 0

-- two arguments matched together, structurally recursive on both
zipLen :: Lst -> Lst -> Int
zipLen LNil _ = 0
zipLen _ LNil = 0
zipLen (LCons _ xs) (LCons _ ys) = 1 + zipLen xs ys

classify :: Shape -> Int
classify s = case s of
  Circle r -> r
  Rect w h -> w * h
  Dot -> 0

-- literals never cover alone: the wildcard does
describe :: Int -> String
describe n = case n of
  0 -> "zero"
  1 -> "one"
  _ -> "many"

-- a tuple of Bools: all four cases
both :: Bool -> Bool -> Int
both a b = case (a, b) of
  (True, True) -> 3
  (True, False) -> 2
  (False, True) -> 1
  (False, False) -> 0

sizeOf :: Shape -> Shape -> Int
sizeOf (Rect w h) _ = w * h
sizeOf _ (Circle r) = r
sizeOf _ _ = 1

orElse :: Maybe Int -> Int -> Int
orElse m d = case m of
  Just x -> x
  Nothing -> d

-- a tuple pattern in a lambda
pairSum :: List (Int, Int) -> Int
pairSum ps = foldl (\acc (a, b) -> acc + a + b) 0 ps

main :: IO ()
main = do
  putStrLn (showInt (firstTwo (LCons 1 (LCons 2 LNil)) + zipLen (LCons 1 LNil) (LCons 2 (LCons 3 LNil))))
  putStrLn (showInt (classify (Rect 2 3) + classify (Circle 4) + classify Dot))
  putStrLn (describe 0 ++ describe 1 ++ describe 7)
  putStrLn (showInt (both True False + both False True + sizeOf Dot (Circle 5) + orElse Nothing 9))
  putStrLn (showInt (pairSum [(1, 2), (3, 4)]))
