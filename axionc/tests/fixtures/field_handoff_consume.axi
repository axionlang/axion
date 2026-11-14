-- A list element handed to a function that STORES it (`consRight` keeps `s` in a new `Cons`)
-- means the list's owner gives the element away, so `keepGood` must own (and shell-free) its
-- list. It used to borrow it: the caller then freed `s` a second time (AX0910).

keepGood :: List String -> Either Int (List String)
keepGood segs = case segs of
  Nil -> Right Nil
  Cons s rest -> if s == ".." then Left 403 else consRight s (keepGood rest)

consRight :: String -> Either Int (List String) -> Either Int (List String)
consRight s r = case r of
  Left e -> Left e
  Right xs -> Right (Cons s xs)

count :: Either Int (List String) -> Int
count r = either (\e -> e) (\xs -> length xs) r

main :: IO ()
main = do
  putStrLn (show (count (keepGood (words "a b c"))))
  putStrLn (show (count (keepGood (words "a .. c"))))
