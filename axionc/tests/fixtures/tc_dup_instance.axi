-- AX0403: two instances for the same (class, type) — incoherence.
class Eq2 a where
  eq2 :: a -> a -> Bool

instance Eq2 Int where
  eq2 x y = x == y

instance Eq2 Int where
  eq2 x y = x < y

main :: Int
main = 1
