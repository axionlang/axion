-- Bloco `do` multi-instrução (IO): desugar sequencial (estrito) para `let`s.
main :: IO ()
main = do
  putStrLn "um"
  putStrLn "dois"
