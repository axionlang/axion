data Color = Red | Green | Blue
  deriving (Eq, Ord)
main :: Bool
main = if le Red Blue then le (maxOr Red [Green, Blue, Red]) Blue else False
