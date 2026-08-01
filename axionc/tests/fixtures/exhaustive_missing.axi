data Color = Red | Green | Blue
rank :: Color -> Int
rank c = case c of
  Red -> 0
  Green -> 1
main :: Int
main = rank Blue
