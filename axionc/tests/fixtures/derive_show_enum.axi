data Color = Red | Green | Blue
  deriving (Eq, Ord, Show)
main :: IO ()
main = putStrLn (show Green)
