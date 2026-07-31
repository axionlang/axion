-- Int core compilable by the native backend (--dev, Cranelift).
-- `axionc --backend cranelift` JIT-compiles and runs main :: Int → 6765.
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

main :: Int
main = fib 20
