-- Closure parameters over heap elements, compiled natively by higher-order specialization.
-- Each user HOF that receives a closure is cloned per closure it is called with
-- (`keepWith gt2` → `keepWith$$gt2`), so the `filter p` inside it sees a known predicate.
-- Covered: a named predicate, a lambda capturing a `do` local, a `let`-bound lambda, a HOF
-- with two closure parameters, a recursive user HOF over the list, `either` with two
-- lambdas, and `map` building records from Ints.
data P = P Int

mkP :: Int -> P
mkP n = P n

-- builds records from a borrowed `List Int`: the verifier used to read `mkP y` as sharing the
-- list's element `y` (an Int, copied) and reject the program as AX0910.
mkPs :: List Int -> List P
mkPs xs = case xs of
  Nil -> Nil
  Cons y ys -> Cons (mkP y) (mkPs ys)

getA :: P -> Int
getA p = case p of
  P a -> a

gt2 :: Integer -> Bool
gt2 n = n > fromInt 2

addI :: Integer -> Integer -> Integer
addI a b = a + b

big :: String -> Bool
big s = strLen s > 1

sumWith :: (Integer -> Bool) -> List Integer -> Integer
sumWith p xs = foldr addI (fromInt 0) (filter p xs)

keepWith :: (String -> Bool) -> List String -> Int
keepWith p xs = length (filter p xs)

keepBoth :: (String -> Bool) -> (String -> Bool) -> List String -> Int
keepBoth p q xs = length (filter p (filter q xs))

countIf :: (String -> Bool) -> List String -> Int
countIf p xs = case xs of
  Nil -> 0
  Cons y ys -> (if p y then 1 else 0) + countIf p ys

main :: IO ()
main = do
  let ws = ["a", "abc", "abcd", "xy"]
  let k = 2
  let short = \s -> strLen s < 4
  putStrLn (show (sumWith gt2 [fromInt 1, fromInt 5, fromInt 7]))
  putStrLn (show (keepWith (\s -> strLen s > k) ["a", "abc", "abcd"]))
  putStrLn (show (keepWith short ["a", "abcde", "xyz"]))
  putStrLn (show (keepBoth (\s -> strLen s > 1) (\s -> strLen s < 4) ["a", "abc", "abcd", "xy"]))
  putStrLn (show (countIf big ws))
  putStrLn (show (either (\l -> l) (\r -> r + 1) (if k > 1 then Left 40 else Right 0)))
  putStrLn (show (foldr (\a b -> a + b) 0 (map getA (map mkP (range 1 5)))))
  putStrLn (show (length (mkPs (range 1 5))))
