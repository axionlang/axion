-- Deve PASSAR e correr: 'split' divide o Config %1 em duas metades %0.5, que
-- são lidas/recombinadas por 'join' (recuperando o %1). level (join a b) == 7.
data Config = Config { level :: Int }

splitJoin :: Config %1 -> Int
splitJoin cfg = case split cfg of
  (a, b) -> level (join a b)

main :: IO ()
main = putStrLn (show (splitJoin (Config { level = 7 })))
