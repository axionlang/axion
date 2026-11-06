-- num_constrained_poly.axi — a `Num a =>`-constrained polymorphic function used at BOTH a
-- primitive (`Int`, resolved to the built-in `+`) and a user type (`V2`, specialized to the
-- instance method `+$V2`). Guards that the constrained-function specializer emits the fast
-- built-in op at a primitive and dispatches to the instance at a user type — no `+$Int` call.
data V2 = V2 Int Int

addV :: V2 -> V2 -> V2
addV a b = case a of
  V2 ax ay -> case b of
    V2 bx by -> V2 (ax + bx) (ay + by)

instance Num V2 where
  (+) a b = addV a b
  (-) a b = addV a b
  (*) a b = addV a b
  fromInteger n = V2 n n

fstV :: V2 -> Int
fstV v = case v of V2 x y -> x

sum3 :: Num a => a -> a -> a -> a
sum3 x y z = x + y + z

main :: IO ()
main = do
  putStrLn (showInt (sum3 1 2 3))                        -- 6   (Int: built-in +)
  putStrLn (showInt (fstV (sum3 (V2 1 0) (V2 2 0) (V2 3 0)))) -- 6   (V2: +$V2)
