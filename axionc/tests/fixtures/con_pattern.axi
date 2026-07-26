-- Padrão de construtor no `case` (tipo de um só construtor): destructura por
-- posição, sem tag. `case p of Point a b -> a + b`. main = 3 + 4 = 7.
data Point = Point { x :: Int, y :: Int }

sumP :: Point -> Int
sumP p = case p of
  Point a b -> a + b

main :: Int
main = sumP (Point { x = 3, y = 4 })
