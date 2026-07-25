-- Buffer (§4): iota cria [0..100), sumBuffer soma (redução vectorizável no
-- --release), freeBuffer liberta. sum(0..99) = 4950.
main :: Int
main =
  let buf = iota 100 in
  let s = sumBuffer buf in
  let done = freeBuffer buf in
  s
