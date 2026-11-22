-- A contract that cannot be proven is checked at run time, and here it fails: the program
-- stops with a message naming the function, the predicate, the values and the caller.

{-# CONTRACT withdraw
      requires 0 <= amount && amount <= balance #-}
withdraw :: Int -> Int -> Int
withdraw balance amount = balance - amount

digits :: String -> Int
digits s = strLen s

main :: IO ()
main = do
  putStrLn (showInt (withdraw 10 3))
  putStrLn (showInt (withdraw 10 (digits "a long string")))
