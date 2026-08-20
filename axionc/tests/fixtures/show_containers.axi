-- Show for container types: List (manual `[a, b, c]` instance), Maybe and
-- Ordering / Trit (derived, 1-param / nullary). Element `show` (not showArg)
-- keeps nested constructors unparenthesised inside the brackets, matching
-- Haskell's `show [Just 1, Nothing]`. Nested lists nest their brackets.
-- Identical output on interp == cranelift == llvm.
double :: Int -> Int
double x = x + x

main :: IO ()
main = do
  putStrLn (show (map double (range 1 5)))
  putStrLn (show (Just 3))
  putStrLn (show (Cons (Just 1) (Cons Nothing Nil)))
  putStrLn (show LT)
  putStrLn (show TPlus)
  putStrLn (show (Cons (Cons 1 Nil) (Cons (Cons 2 (Cons 3 Nil)) Nil)))
