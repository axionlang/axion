-- AX0204: a string-pattern `case` with no catch-all is never exhaustive.
f :: String -> Int
f x = case x of
  "a" -> 1
  "b" -> 2
main :: Int
main = f "a"
