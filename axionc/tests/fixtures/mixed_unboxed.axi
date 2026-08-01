data Opt a = Nothing | Just a
unwrap :: Int -> Opt Int -> Int
unwrap d o = case o of
  Nothing -> d
  Just x -> x
main :: Int
main = unwrap 5 Nothing + unwrap 0 Nothing
