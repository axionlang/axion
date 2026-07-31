-- FFI (§18): calls libc's `labs` (Int ABI), resolved via dlsym in all three
-- executors (interp/--dev/--release). labs(-42) = 42.
foreign labs :: Int -> Int

main :: Int
main = labs (0 - 42)
