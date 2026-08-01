data Maybe a = None | Some a
  deriving (Eq, Ord, Show)
main :: Bool
main = if le None (Some 3) then eq (Some 5) (Some 5) else False
