-- Executable arena (§3): 'withArena' creates the root arena, 'allocN' bump-allocates
-- N cells inside it, and at the end the arena is reclaimed in ONE go (a single reset,
-- not N frees). main = withArena (\a -> allocN a 100) = 100 → 100 cells, 1 reset.
useCell :: Cell -> Int
useCell c = 0

allocN :: Arena -> Int -> Int
allocN a 0 = 0
allocN a n =
  let c = allocateCell a in
  let u = useCell c in
  1 + allocN a (n - 1)

main :: Int
main = withArena (\a -> allocN a 100)
