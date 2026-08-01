data Color = Red | Green | Blue
  deriving (Eq, Ord, Show)
data Maybe a = None | Some a
  deriving (Eq, Ord, Show)
main :: IO ()
main = putStrLn (show (Some Green))
