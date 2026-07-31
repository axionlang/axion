-- `++` on lists (concatenation) lowers to the prelude's `append` — first order,
-- so it runs in all three executors (interp, --dev/Cranelift, --release/LLVM).
main :: Int
main = sum ([1, 2] ++ [3, 4] ++ [10])
