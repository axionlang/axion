-- Richer strings: concatenation `++`, unwords (joins with spaces), unlines
-- (joins with '\n'). Builds text from lists — dogfooding the prelude.
main :: IO ()
main = putStr (unwords ["Hello", "Axion"] ++ "!\n" ++ unlines ["line 1", "line 2"])
