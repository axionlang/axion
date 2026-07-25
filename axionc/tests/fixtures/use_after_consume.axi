-- Deve FALHAR com AX0001: 'x' (%1) é CONSUMIDO duas vezes (devolvido em ambos
-- os slots do tuplo). Ler duas vezes (x + x) seria permitido — são empréstimos;
-- consumir/mover duas vezes é que é contração.
useTwice :: Int %1 -> (Int, Int)
useTwice x = (x, x)
