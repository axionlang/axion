-- `sumtype` kernel (§ unboxing): 200M steps (4000×50000) over an UNBOXED enum.
-- `turn`/`val` are `case` dispatch on `Dir`; each `Dir` is an immediate tag (the
-- constructor index), so the hot loop does ZERO heap allocation — the same shape
-- as a C `enum` + `switch`. The starting direction depends on `k` (via `fromInt`)
-- so the inner result is not loop-invariant (no hoisting by -O2).
data Dir = North | East | South | West

turn :: Dir -> Dir
turn d = case d of
  North -> East
  East -> South
  South -> West
  West -> North

val :: Dir -> Int
val d = case d of
  North -> 0
  East -> 1
  South -> 2
  West -> 3

fromInt :: Int -> Dir
fromInt n = case (n `mod` 4) of
  0 -> North
  1 -> East
  2 -> South
  _ -> West

inner :: Dir -> Int -> Int -> Int
inner d acc 0 = acc
inner d acc n = inner (turn d) ((acc + val d) `mod` 1000000) (n - 1)

outer :: Int -> Int -> Int
outer acc 0 = acc
outer acc k = outer ((acc + inner (fromInt k) 0 50000) `mod` 2147483647) (k - 1)

main :: Int
main = outer 0 4000
