-- Deve PASSAR: o recurso linear 'x' (%1) é consumido exactamente uma vez.
useOnce :: Int %1 -> Int
useOnce x = x + 1
