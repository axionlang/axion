-- Monomorphization (slice 2b-ii): method calls on statically concrete receivers
-- are rewritten to direct calls to the impl (`sz (Box 10)` →
-- `sz$Box (Box 10)`), so they COMPILE NATIVELY. Runs in all three executors
-- (interp, --dev/Cranelift, --release/LLVM), all yielding 20.
-- Instances written with `case`/arithmetic (native-friendly): constructor patterns
-- in multi-clause heads are still interp-only (an orthogonal native limitation).
class Sized a where
  sz :: a -> Int

data Box = Box Int

instance Sized Box where
  sz b = case b of
    Box n -> n

instance Sized Int where
  sz x = x * 2

main :: Int
main = sz (Box 10) + sz 5
