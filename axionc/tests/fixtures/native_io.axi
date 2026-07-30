-- IO/efeitos NATIVOS (1ª fatia da estrada M:N): do-blocks sequenciam, `mapM_`
-- (agora função de prelúdio, não builtin) percorre a lista aplicando a acção, e
-- `putStr`/`putStrLn` são runtime nativo. Corre nos três executores.
-- Saída: "sum=6\n2\n4\n6\n".
double :: Int -> Int
double n = n + n

main :: IO ()
main = do
  putStr "sum="
  putStrLn (show 6)
  mapM_ (\n -> putStrLn (show (double n))) [1, 2, 3]
