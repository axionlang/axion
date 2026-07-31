-- Linear Elision (§2): 'bump' updates a %1 Cell at its last live mention →
-- the compiler mutates the existing block (an `update!` node in Core) instead of
-- alloc+copy. Result 99, with just 1 allocation (the Cell), not 2.
data Cell = Cell { val :: Int }

bump :: Cell %1 -> Cell %1
bump c = c { val = 99 }

main :: Int
main =
  let c0 = Cell { val = 1 } in
  let c1 = bump c0 in
  let r = val c1 in
  r
