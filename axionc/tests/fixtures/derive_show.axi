data Shape = Circle Int | Rect Int Int
  deriving (Show)
main :: IO ()
main = putStrLn (show (Rect 2 3))
