-- `dispatch` kernel (§ zero-cost): 200M steps (4000×50000, nested loops —
-- bounded depth) where the hot operation is a typeclass METHOD.
-- `inner :: Stepper a =>` is generic; monomorphization (slice 2b) specializes it
-- to `inner$Int` with `step → step$Int`, and LLVM -O2 -flto inlines the method —
-- zero-cost abstraction, à la Rust. `step` uses `mod` (not foldable by -O2).
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
