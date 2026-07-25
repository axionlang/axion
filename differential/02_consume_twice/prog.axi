-- Contração: 'x' (%1) é CONSUMIDO duas vezes (movido para ambos os slots) →
-- REJEITADO (AX0001). Nota: ler duas vezes (x + x) seria aceite — são
-- empréstimos; é o consumo/move duplo que é proibido (como no GHC).
useTwice :: Int %1 -> (Int, Int)
useTwice x = (x, x)
