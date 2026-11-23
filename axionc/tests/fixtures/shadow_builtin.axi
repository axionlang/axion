-- A program may define a function with a built-in's name; its own definition is what it calls,
-- on every backend (natively the built-in used to win: `fromInt` called the bignum one).

fromInt :: Int -> Int
fromInt n = n * 2 + 1

toFloat :: Int -> Int
toFloat n = n + 100

abs :: Int -> Int
abs n = if n < 0 then 0 - n * 10 else n * 10

lenArray :: Int -> Int
lenArray n = n - 1

-- a `where`-local with a built-in's name
twice :: Int -> Int
twice n = sqrt (sqrt n)
  where sqrt k = k * 2

main :: IO ()
main = do
  putStrLn (showInt (fromInt 20))
  putStrLn (showInt (toFloat 5))
  putStrLn (showInt (abs (0 - 3)))
  putStrLn (showInt (lenArray 7))
  putStrLn (showInt (twice 5))
  putStrLn (showInt (sum (map fromInt [1, 2, 3])))
