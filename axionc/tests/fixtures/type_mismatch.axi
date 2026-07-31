-- Must FAIL with AX0200: 'bad' is declared Int but the body is IO ().
bad :: Int
bad = putStrLn "hi"
