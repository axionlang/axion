-- `/=` (not equal) works for every `Eq` instance: Int, Float, String, a `deriving Eq` type; it
-- binds like `==` (precedence 4), below arithmetic and above `&&`.
data Color = Red | Green deriving (Eq)

main :: IO ()
main = do
  putStrLn (show (3 /= 4))
  putStrLn (show (3 /= 3))
  putStrLn (show ("ab" /= "ab"))
  putStrLn (show ("ab" /= "ac"))
  putStrLn (show (Red /= Green))
  putStrLn (show (1 + 2 /= 3 && 2 /= 1))
  putStrLn (show (2.5 /= 2.5))
