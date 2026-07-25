-- Deve FALHAR com AX0004: 'x' é consumido por 'sink x' (a posse sai) e depois
-- lido outra vez em '+ x'. Ler ANTES de consumir (x + sink x) seria OK.
sink :: Int %1 -> Int
sink x = x

bad :: Int %1 -> Int
bad x = sink x + x
