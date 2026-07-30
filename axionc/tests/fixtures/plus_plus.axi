-- `++` sobre listas (concatenação) baixa ao `append` do prelúdio — 1ª ordem,
-- logo corre nos três executores (interp, --dev/Cranelift, --release/LLVM).
main :: Int
main = sum ([1, 2] ++ [3, 4] ++ [10])
