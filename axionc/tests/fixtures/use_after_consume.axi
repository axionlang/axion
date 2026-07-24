-- Deve FALHAR com AX0001: o recurso linear 'x' (%1) é usado duas vezes.
useTwice :: Int %1 -> Int
useTwice x = x + x
