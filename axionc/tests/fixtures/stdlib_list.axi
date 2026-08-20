-- Exercises the prelude list functions added in the stdlib-growth batch:
-- takeWhile, dropWhile, span, splitAt, concatMap, product, and, or, lookup, findIndex.
-- Expected output (interp == cranelift == llvm):
--   720 / 10 / 11 / 21 / 21 / 12 / True / False / 20 / 2
lt5 :: Int -> Bool
lt5 n = n < 5

dup :: Int -> List Int
dup n = Cons n (Cons n Nil)

sumPair :: (List Int, List Int) -> Int
sumPair ab = case ab of
  (a, b) -> sum a + sum b

main :: IO ()
main = do
  putStrLn (show (product (range 1 6)))
  putStrLn (show (sum (takeWhile lt5 (range 1 10))))
  putStrLn (show (sum (dropWhile lt5 (range 1 6))))
  putStrLn (show (sumPair (span lt5 (range 1 6))))
  putStrLn (show (sumPair (splitAt 2 (range 1 6))))
  putStrLn (show (sum (concatMap dup (range 1 3))))
  putStrLn (show (and (Cons True (Cons True Nil))))
  putStrLn (show (or (Cons False (Cons False Nil))))
  putStrLn (show (fromMaybe 99 (lookup 2 (Cons (1, 10) (Cons (2, 20) Nil)))))
  putStrLn (show (fromMaybe 99 (findIndex lt5 (Cons 9 (Cons 8 (Cons 2 Nil))))))
