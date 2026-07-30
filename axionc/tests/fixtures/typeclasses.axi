-- Typeclasses (fatia 1): class/instance + despacho dinâmico pela cabeça-de-tipo
-- do 1º argumento, e polimorfismo restrito `C a =>` (constraints parseados e
-- ignorados; o despacho é dinâmico). Demonstra: duas classes, métodos sobre Int
-- e sobre um `data`, uma instância que REUTILIZA métodos de outra, e uma função
-- genérica `count :: Eq a =>`. Total = 3 + 10 + 12 + 100 = 125.
class Eq a where
  eq :: a -> a -> Bool

class Size a where
  size :: a -> Int

data Shape = Circle Int | Rect Int Int

instance Eq Int where
  eq x y = x == y

instance Size Shape where
  size s = case s of
    Circle r -> r
    Rect w h -> w * h

instance Eq Shape where
  eq a b = eq (size a) (size b)

count :: Eq a => a -> List a -> Int
count x xs = case xs of
  Nil -> 0
  Cons y ys -> if eq x y then 1 + count x ys else count x ys

main :: Int
main =
  count 2 [1, 2, 2, 3, 2]
  + size (Circle 10)
  + size (Rect 3 4)
  + (if eq (Circle 12) (Rect 3 4) then 100 else 0)
