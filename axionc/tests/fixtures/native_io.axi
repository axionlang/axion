-- NATIVE IO/effects (1st slice of the M:N road): do-blocks sequence, `mapM_`
-- (now a prelude function, not a builtin) walks the list applying the action, and
-- `putStr`/`putStrLn` are native runtime. Runs in all three executors.
-- Output: "sum=6\n2\n4\n6\n".
double :: Int -> Int
double n = n + n

main :: IO ()
main = do
  putStr "sum="
  putStrLn (show 6)
  mapM_ (\n -> putStrLn (show (double n))) [1, 2, 3]
