-- 40M células em arenas (§3): withArena bump-aloca 20000/chamada, reset em massa.
useCell :: Cell -> Int
useCell c = 0

allocN :: Arena -> Int -> Int
allocN a 0 = 0
allocN a n =
  let c = allocateCell a in
  let u = useCell c in
  1 + allocN a (n - 1)

loop :: Int -> Int
loop 0 = 0
loop k = withArena (\a -> allocN a 20000) + loop (k - 1)

main :: Int
main = loop 2000
