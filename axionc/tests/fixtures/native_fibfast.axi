-- Native backend: multi-clause + 'where'. 'go' (local, multi-clause with a
-- literal pattern '0') is lifted to 'fibFast$go' and compiled with recursion.
-- `axionc --backend cranelift` → fibFast 30 == 832040.
fibFast :: Int -> Int
fibFast n = go n 0 1
  where
    go 0 a _ = a
    go k a b = go (k - 1) b (a + b)

main :: Int
main = fibFast 30
