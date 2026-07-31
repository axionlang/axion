-- Constructor pattern in `case` (single-constructor type): destructures by
-- position, no tag. `case p of Point a b -> a + b`. main = 3 + 4 = 7.
data Point = Point { x :: Int, y :: Int }

sumP :: Point -> Int
sumP p = case p of
  Point a b -> a + b

main :: Int
main = sumP (Point { x = 3, y = 4 })
