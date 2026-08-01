data Color = Red | Green | Blue
rank :: Color -> Int
rank c = case c of
  Red -> 0
  _ -> 1
  Blue -> 2
main :: Int
main = rank Red
