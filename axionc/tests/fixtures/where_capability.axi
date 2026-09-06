-- Regression (#4): a `where`-bound capability call (`getEnv`) must lower on the native
-- backends — the lambda-lift previously captured the builtin name `getEnv` as a
-- parameter, leaving an unbound `getEnv` in the IR. Reads $AXION_WHERE_TEST.
val :: Int -> String
val d
  | strLen s > 0 = s
  | otherwise    = "default"
  where s = getEnv "AXION_WHERE_TEST"

main :: IO ()
main = putStr (val 0)
