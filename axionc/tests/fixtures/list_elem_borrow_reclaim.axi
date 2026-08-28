-- Borrowed-then-dead element of a `%1`-consumed list: `sumV` reads a heap record's
-- scalar field (`v h`, a borrow) then DISCARDS the element and recurses on the tail.
-- Auto-Drop must drop each `Box h` AFTER the read (not before → the `UseAfterFree`,
-- and not never → a leak). The recursing spine forces the non-deep `Inline` path.
-- 2 Cons + 2 Box = 4 allocs, all 4 freed; 3 + 4 = 7.

data Box = Box { v :: Int }

sumV :: List Box %1 -> Int
sumV xs = case xs of
  Nil -> 0
  Cons h t -> v h + sumV t

main :: Int
main = sumV (Cons (Box { v = 3 }) (Cons (Box { v = 4 }) Nil))
