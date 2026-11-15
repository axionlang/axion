-- `Integer` fields of `data`/record values are reclaimed like `String` fields: the destructor
-- frees them, and an extracted field is MOVED out (the container frees only the rest). Covers
-- a container dropped with its Integer field unread (it leaked: `con_drop_slots` used to exclude
-- Integer, and the verifier was blind to it), the same field read twice (refused natively,
-- AX0913, while the String twin compiled), an unboxing getter, a record field, and `map` of a
-- field getter over a list of such records. Leak-gated by sanitize.sh.
data R = R Integer Int
data Pair = Pair Integer Integer
data BoxI = BoxI Integer
data P = P { name :: Integer, age :: Int }

getF :: Pair -> Integer
getF p = case p of
  Pair a b -> a

useBoth :: Pair -> Integer
useBoth p = getF p + getF p

unbox :: BoxI -> Integer
unbox b = case b of
  BoxI n -> n

getV :: R -> Integer
getV r = case r of
  R v k -> v

main :: IO ()
main = do
  let dropped = R (fromInt 5) 1
  putStrLn (showInteger (useBoth (Pair (fromInt 123) (fromInt 4))))
  putStrLn (showInteger (unbox (BoxI (fromInt 42))))
  let p = P { name = fromInt 77, age = 3 }
  putStrLn (showInteger (name p))
  let q = P { name = fromInt 78, age = 4 }
  putStrLn (showInt (age q))
  putStrLn (show (map getV (Cons (R (fromInt 1) 1) (Cons (R (fromInt 22) 2) Nil))))
