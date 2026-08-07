-- Integration stress: `parMap` + `Integer` + session workers doing arbitrary-
-- precision compute (§9 + §Listing 1.4). Four workers each compute `factorial 20`
-- as an `Integer` and send it back; parMap collects a `List Integer`; `foldr`
-- sums them. 4 × 20! = 9731608032706560000 OVERFLOWS i64, but is exact with
-- Integer. This exercises Integer values flowing through channels and the fork-join,
-- and Integer builtins (`fromInt`) inside a native session worker. All three
-- executors agree; ASan-clean.
factorial :: Integer -> Integer
factorial n = if n < 2 then 1 else n * factorial (n - 1)

worker :: Ep (Recv Int (Send Integer End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (factorial (fromInt n))
  close d3

addI :: Integer -> Integer -> Integer
addI a b = a + b

main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (parMap worker (replicate 4 20))))
