data Opt a = None | Some a
unwrap :: Int -> Opt Int -> Int
unwrap d o = case o of
  None -> d
  Some x -> x
main :: Int
main = unwrap 5 None + unwrap 0 None
