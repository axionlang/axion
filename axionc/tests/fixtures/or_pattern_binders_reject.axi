-- REJECT (AX0100): the alternatives of an or-pattern bind different variables.
f :: Maybe Int -> Int
f m = case m of
  Just x | Nothing -> 1

main :: Int
main = f Nothing
