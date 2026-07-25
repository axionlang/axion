-- Arena executável (§3): 'withArena' cria a arena-raiz, 'allocN' bump-aloca N
-- células lá dentro, e no fim a arena é reclamada de UMA vez (um só reset, não
-- N frees). main = withArena (\a -> allocN a 100) = 100 → 100 células, 1 reset.
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
