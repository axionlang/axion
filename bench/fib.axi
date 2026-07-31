-- Compute-bound micro-benchmark: recursive fib (naive). Compiles on the native
-- --dev backend (Cranelift). `axionc --backend cranelift bench/fib.axi`.
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

main :: Int
main = fib 40
