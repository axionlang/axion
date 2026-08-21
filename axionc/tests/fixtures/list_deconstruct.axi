-- Safe list deconstruction: uncons / head / tail / last. `uncons` is the linear
-- primitive — it yields the head AND the rest as a pair, so nothing is aliased or
-- double-freed; head/tail/last return one part and drop the other (the list arg is
-- consume-inferred `%1`). `Nothing` on an empty list, and composes with `drop`.
-- Identical output on interp == cranelift == llvm.
main :: IO ()
main = do
  putStrLn (show (uncons (Cons 1 (Cons 2 (Cons 3 Nil)))))
  putStrLn (show (head (Cons 7 (Cons 8 Nil))))
  putStrLn (show (tail (Cons 7 (Cons 8 (Cons 9 Nil)))))
  putStrLn (show (last (Cons 4 (Cons 5 (Cons 6 Nil)))))
  putStrLn (show (head (drop 5 (range 1 3))))
  putStrLn (show (last (map double (range 1 4))))

double :: Int -> Int
double x = x + x
