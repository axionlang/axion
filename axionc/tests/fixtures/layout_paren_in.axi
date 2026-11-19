-- An `in` inside a bracket opened AFTER a `let` belongs to that bracket's own construct (a `borrow …
-- as … in`, a nested `let … in`), not to the outer `let`'s implicit block — it used to close it
-- ("expected 'in' in a borrow scope, found end of block").
f :: Int -> Int
f n =
  let q = n
          + (let m = n * 2 in m + 1) in
  q * 10

g :: Int -> Int
g n =
  let b = newBuffer 8 in
  let w = pokeU64 b 0 n + peekU64 b 0
          + (borrow b as p in p * 0 + 3) in
  w

main :: IO ()
main = putStrLn (showInt (f 4) ++ " " ++ showInt (g 5))
