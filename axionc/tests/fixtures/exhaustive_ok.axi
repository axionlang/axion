data Color = Red | Green | Blue
rank :: Color -> Int
rank c = case c of
  Red -> 0
  Green -> 1
  Blue -> 2
main :: Int
main = rank Blue
