-- Must PASS and run: 'split' divides the %1 Config into two %0.5 halves, which
-- are read/recombined by 'join' (recovering the %1). level (join a b) == 7.
data Config = Config { level :: Int }

splitJoin :: Config %1 -> Int
splitJoin cfg = case split cfg of
  (a, b) -> level (join a b)

main :: IO ()
main = putStrLn (show (splitJoin (Config { level = 7 })))
