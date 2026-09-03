-- `sortBy` with a user comparator (descending). Exercises the closure-capture borrow fix:
-- sortBy's partition lambdas capture both the comparator and the pivot, used across two
-- closures + the final `Cons y` — previously an AX0910 false positive in the specialized
-- clone. Leak-free with a named comparator (verifier + ASan + LSan clean on every backend).
ge :: Int -> Int -> Bool
ge a b = if a > b then True else a == b

main :: IO ()
main = putStrLn (show (sum (sortBy ge (Cons 2 (Cons 9 (Cons 1 (Cons 5 Nil)))))))
