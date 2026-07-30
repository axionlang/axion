-- Strings mais ricas: concatenação `++`, unwords (junta com espaços), unlines
-- (junta com '\n'). Constrói texto a partir de listas — dogfooding do prelúdio.
main :: IO ()
main = putStr (unwords ["Olá", "Axión"] ++ "!\n" ++ unlines ["linha 1", "linha 2"])
