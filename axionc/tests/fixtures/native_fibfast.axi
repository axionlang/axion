-- Backend nativo: multi-cláusula + 'where'. 'go' (local, multi-cláusula com
-- padrão literal '0') é liftado para 'fibFast$go' e compilado com recursão.
-- `axionc --backend cranelift` → fibFast 30 == 832040.
fibFast :: Int -> Int
fibFast n = go n 0 1
  where
    go 0 a _ = a
    go k a b = go (k - 1) b (a + b)

main :: Int
main = fibFast 30
