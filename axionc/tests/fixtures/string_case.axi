-- String-literal `case` patterns (desugared to an `if`-chain over strCmp). The
-- catch-all `other` binds the scrutinee. classify "one"=1 "two"=2 "three"=3 else 0.
classify :: String -> Int
classify s = case s of
  "one"   -> 1
  "two"   -> 2
  "three" -> 3
  other   -> if strLen other == 0 then 9 else 0

main :: Int
main = classify "one" + classify "two" * 10 + classify "three" * 100 + classify "" * 1000
