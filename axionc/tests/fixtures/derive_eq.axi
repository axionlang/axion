data Shape = Circle Int | Rect Int Int
  deriving (Eq)
main :: Bool
main = if eq (Rect 2 3) (Rect 2 3) then eq (Circle 1) (Rect 0 0) else False
