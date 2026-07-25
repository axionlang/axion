-- Deve PASSAR: ler um %1 duas vezes são dois EMPRÉSTIMOS (Elisão de
-- Empréstimos, §2), não uma contração. O Auto-Drop injecta 'free' após a
-- última leitura (o segundo 'x').
readTwice :: Int %1 -> Int
readTwice x = x + x
