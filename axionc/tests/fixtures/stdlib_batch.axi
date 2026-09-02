-- Prelude breadth batch: function combinators (id/const/flip/fst/snd/curry/uncurry),
-- Maybe helpers (mapMaybe/maybeToList/listToMaybe), and elemIndex. All leak-free
-- over scalar element types (verifier + ASan + LSan clean on every backend).
half :: Int -> Maybe Int
half n = Just (n + n)

idxOr :: Maybe Int -> Int
idxOr m = case m of
  Just i -> i
  Nothing -> 0

main :: IO ()
main = putStrLn (show
  ( fst (10, 99)
  + snd (7, 5)
  + flip minus 3 20
  + curry fst 4 100
  + uncurry minus (30, 1)
  + length (mapMaybe half (Cons 1 (Cons 2 Nil)))
  + length (maybeToList (Just 5))
  + idxOr (listToMaybe (Cons 6 Nil))
  + idxOr (elemIndex 3 (Cons 1 (Cons 3 Nil)))
  + const 6 True
  + id 1 ))

minus :: Int -> Int -> Int
minus x y = x - y
