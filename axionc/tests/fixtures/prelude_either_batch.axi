-- Tier 1.2 prelude growth: Either utilities (fromLeft/fromRight/lefts/rights/
-- partitionEithers/mapLeft/mapRight), Ord `compare`, tuple `swap`, and list
-- `isPrefixOf`/`isSuffixOf`. fromLeft/fromRight delegate through `either` (not a bare
-- interior return) so they are sound over heap payloads too (String here). lefts/rights/
-- partitionEithers over a HEAP element payload hit the documented partial-consumer floor
-- (AX0910-gated, like `catMaybes`), so the Either-collection cases use Int payloads;
-- read-only / fresh-rebuild combinators are exercised over String.
l7 :: Either Int Int
l7 = Left 7
r8 :: Either Int Int
r8 = Right 8
es :: List (Either Int Int)
es = Cons (Left 1) (Cons (Right 2) (Cons (Left 3) (Cons (Right 4) Nil)))
ls :: Either String Int
ls = Left "hi"

main :: IO ()
main = do
  putStrLn (showInt (fromLeft 0 l7))
  putStrLn (showInt (fromRight 0 r8))
  putStrLn (showInt (fromLeft 99 r8))
  putStrLn (fromLeft "z" ls)
  putStrLn (show (lefts es))
  putStrLn (show (rights es))
  putStrLn (show (partitionEithers es))
  putStrLn (show (mapLeft (\x -> x + 100) l7))
  putStrLn (show (mapRight (\x -> x + 100) r8))
  putStrLn (show (mapRight (\x -> x + 100) l7))
  putStrLn (show (compare 3 5))
  putStrLn (show (compare 9 5))
  putStrLn (show (swap (1, 2)))
  putStrLn (show (isPrefixOf (Cons "a" Nil) (Cons "a" (Cons "b" Nil))))
  putStrLn (show (isSuffixOf (Cons "b" (Cons "c" Nil)) (Cons "a" (Cons "b" (Cons "c" Nil)))))
