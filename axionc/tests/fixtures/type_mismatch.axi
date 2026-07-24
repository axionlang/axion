-- Deve FALHAR com AX0200: 'bad' é declarado Int mas o corpo é IO ().
bad :: Int
bad = putStrLn "olá"
