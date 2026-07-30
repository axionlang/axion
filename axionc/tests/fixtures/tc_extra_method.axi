-- AX0402: a instância implementa um método que a classe não declara.
class Eq2 a where
  eq2 :: a -> a -> Bool

instance Eq2 Int where
  eq2 x y = x == y
  bogus x = x

main :: Int
main = 1
