-- A program's own `complement` / `popCount` replace the prelude's.
complement :: Int -> Int
complement x = 100 - x

popCount :: List Int -> Int
popCount xs = length xs

main :: IO ()
main = do
  putStrLn (showInt (complement 1))
  putStrLn (showInt (popCount [1, 2, 3]))
