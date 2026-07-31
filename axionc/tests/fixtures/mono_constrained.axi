-- Monomorphization of CONSTRAINED functions (slice 2b-β): `count :: Eq a =>` is
-- specialized per concrete type at the call-site — `count 2 [..]` generates `count$Int`
-- with `eq → eq$Int` and the recursion `count → count$Int`. Thus constrained
-- polymorphism compiles NATIVELY (Rust-style monomorphization, zero-cost). Runs
-- in all three executors (interp, --dev/Cranelift, --release/LLVM), all → 3.
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
