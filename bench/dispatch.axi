-- Kernel `dispatch` (§ zero-cost): 200M passos (4000×50000, laços encaixados —
-- profundidade limitada) em que a operação quente é um MÉTODO de typeclasse.
-- `inner :: Stepper a =>` é genérica; a monomorfização (fatia 2b) especializa-a
-- a `inner$Int` com `step → step$Int`, e o LLVM -O2 -flto inlina o método —
-- abstração de custo-zero, à Rust. `step` usa `mod` (não-fechável pelo -O2).
class Stepper a where
  step :: a -> a

instance Stepper Int where
  step x = (x + 7) `mod` 1000000

inner :: Stepper a => a -> Int -> a
inner x 0 = x
inner x n = inner (step x) (n - 1)

outer :: Int -> Int -> Int
outer acc 0 = acc
outer acc k = outer ((acc + inner k 50000) `mod` 2147483647) (k - 1)

main :: Int
main = outer 0 4000
