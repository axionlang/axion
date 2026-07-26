-- FFI (§18): chama a `labs` da libc (ABI de Int), resolvida por dlsym nos três
-- executores (interp/--dev/--release). labs(-42) = 42.
foreign labs :: Int -> Int

main :: Int
main = labs (0 - 42)
