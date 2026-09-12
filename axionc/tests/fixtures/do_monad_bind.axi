-- Explicit per-monad `do`-bind (§ error-handling ergonomics): `<-?` short-circuits on
-- Maybe's `Nothing`, `<-!` short-circuits on Either's `Left` (re-wrapping the error). Both
-- desugar SYNTACTICALLY (no type inference, no HKT) to exactly the `case` a hand-written
-- version writes — `x <-? e` → `case e of Just x -> rest; Nothing -> Nothing`; `x <-! e` →
-- `case e of Right x -> rest; Left err -> Left err`. Plain `<-` stays IO sequencing.
safeDiv :: Int -> Int -> Maybe Int
safeDiv a b = if b == 0 then Nothing else Just (a `div` b)

calc :: Int -> Int -> Int -> Maybe Int
calc a b c = do
  x <-? safeDiv a b
  y <-? safeDiv x c
  Just (y + 1)

checkPos :: Int -> Either String Int
checkPos n = if n > 0 then Right n else Left "not positive"

both :: Int -> Int -> Either String Int
both a b = do
  x <-! checkPos a
  y <-! checkPos b
  Right (x + y)

showMb :: Maybe Int -> String
showMb m = case m of
  Nothing -> "Nothing"
  Just v -> strAppend "Just " (showInt v)

showE :: Either String Int -> String
showE e = case e of
  Left s -> strAppend "Left " s
  Right v -> strAppend "Right " (showInt v)

main :: IO ()
main = do
  putStrLn (showMb (calc 100 5 2))
  putStrLn (showMb (calc 100 0 2))
  putStrLn (showE (both 3 4))
  putStrLn (showE (both 3 0))
