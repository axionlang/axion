-- num_user_instance.axi — `Num`/`Division` are user-extensible typeclasses (not hardcoded).
-- A user type gets `+ - *` by declaring `instance Num`, and `/` by `instance Division`; the
-- operator use dispatches to the instance method (`+$V2`), while the primitive types keep the
-- fast built-in rewrite. Componentwise 2-vector over `Int` (scalar fields → no heap, LSan-trivial).
data V2 = V2 Int Int

addV :: V2 -> V2 -> V2
addV a b = case a of
  V2 ax ay -> case b of
    V2 bx by -> V2 (ax + bx) (ay + by)

subV :: V2 -> V2 -> V2
subV a b = case a of
  V2 ax ay -> case b of
    V2 bx by -> V2 (ax - bx) (ay - by)

mulV :: V2 -> V2 -> V2
mulV a b = case a of
  V2 ax ay -> case b of
    V2 bx by -> V2 (ax * bx) (ay * by)

divV :: V2 -> V2 -> V2
divV a b = case a of
  V2 ax ay -> case b of
    V2 bx by -> V2 (ax / bx) (ay / by)

instance Num V2 where
  (+) a b = addV a b
  (-) a b = subV a b
  (*) a b = mulV a b
  fromInteger n = V2 n n

instance Division V2 where
  (/) a b = divV a b

fstV :: V2 -> Int
fstV v = case v of V2 x y -> x
sndV :: V2 -> Int
sndV v = case v of V2 x y -> y

showV :: V2 -> String
showV v = strAppend (showInt (fstV v)) (strAppend " " (showInt (sndV v)))

main :: IO ()
main = do
  putStrLn (showV (V2 1 2 + V2 3 4))   -- 4 6
  putStrLn (showV (V2 10 9 - V2 3 4))  -- 7 5
  putStrLn (showV (V2 2 3 * V2 3 4))   -- 6 12
  putStrLn (showV (V2 20 12 / V2 5 4)) -- 4 3
