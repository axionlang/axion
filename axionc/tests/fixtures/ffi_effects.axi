-- FFI effects: every `foreign` import is effectful unless declared `foreign pure`, so an
-- unused `where` binding that calls one (directly or through a wrapper) warns AX0920 —
-- `where` is demand-evaluated and the call would silently never run. `--emit ffi` lists
-- every import and call site of this file. (Compile-checked only.)
foreign "libc.so.6" cputs = "puts" :: String -> Int
foreign pure "libm.so.6" csqrt = "sqrt" :: Float -> Float
foreign pure "libc.so.6" cabs = "labs" :: Int -> Int
foreign pure :: Int -> Int

logLine :: String -> Int
logLine s = cputs s

apply :: (Int -> Int) -> Int -> Int
apply f x = f x

shadowed :: Int -> Int
shadowed cabs = cabs + 1

main :: Int
main = apply cabs (0 - 7) + shadowed 1
  where
    direct = cputs "direct"
    wrapped = logLine "wrapped"
    root = csqrt 2.0
