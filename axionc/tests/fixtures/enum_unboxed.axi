data Dir = North | East | South | West
turn :: Dir -> Dir
turn d = case d of
  North -> East
  East -> South
  South -> West
  West -> North
main :: Int
main = case turn (turn North) of
  South -> 1
  _ -> 0
