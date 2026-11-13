-- `filter` consumes the list it is given, so a function passing a field of its argument to
-- `filter` owns the argument. When the `filter` call was the scrutinee of a `case`, ownership
-- inference missed that move (it only looked at the arms), the function borrowed its argument,
-- and the verifier rejected the result as an internal error (AX0910). It now takes ownership,
-- and using the object twice is reported at the call site (AX0001, naming `field`).
data J = JNum Int | JObj (List (String, Int))

keyIs :: String -> (String, Int) -> Bool
keyIs k m = case m of
  (a, b) -> a == k

field :: String -> J -> Int
field k v = case v of
  JObj ms -> case filter (keyIs k) ms of
    Nil -> 0
    Cons m rest -> case m of
      (a, b) -> b + strLen a
  other -> 0

main :: Int
main = field "2" (JObj [(show 1, 10), (show 2, 20), (show 3, 30)])
