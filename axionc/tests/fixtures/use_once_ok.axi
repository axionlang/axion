-- Must PASS: the linear resource 'x' (%1) is consumed exactly once.
useOnce :: Int %1 -> Int
useOnce x = x + 1
