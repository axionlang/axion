-- AX0401: the instance does not implement all of the class's methods.
class Eq2 a where
  eq2 :: a -> a -> Bool
  ne2 :: a -> a -> Bool

instance Eq2 Int where
  eq2 x y = x == y

main :: Int
main = 1
