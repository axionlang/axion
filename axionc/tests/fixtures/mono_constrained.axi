-- Monomorfização de funções CONSTRANGIDAS (fatia 2b-β): `count :: Eq a =>` é
-- especializada por tipo concreto no call-site — `count 2 [..]` gera `count$Int`
-- com `eq → eq$Int` e a recursão `count → count$Int`. Assim o polimorfismo
-- restrito compila NATIVAMENTE (monomorfização estilo Rust, zero-cost). Corre
-- nos três executores (interp, --dev/Cranelift, --release/LLVM), todos → 3.
class Eq a where
  eq :: a -> a -> Bool

instance Eq Int where
  eq x y = x == y

count :: Eq a => a -> List a -> Int
count x xs = case xs of
  Nil -> 0
  Cons y ys -> if eq x y then 1 + count x ys else count x ys

main :: Int
main = count 2 [1, 2, 2, 3, 2]
