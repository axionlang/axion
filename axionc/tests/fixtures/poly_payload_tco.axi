-- TCO-compatible deep drop (§2): `loop` owns the list (`%1`), BORROWS a scalar
-- field (`a y :: Int`) and tail-recurses. The deep drop of the scrutinee is placed
-- AFTER the last use of the payload (`a y`) but BEFORE the tail call, so the call
-- stays in tail position (compiled to a jump, constant native stack) rather than
-- being pushed out of tail position by an exit-placed drop. `a y` reads a scalar,
-- so the value survives the drop; the whole list is reclaimed each step.
-- build 3 → 3+3 objects, then build 2, build 1 → 12 allocs, all reclaimed; = 0.
data P = P { a :: Int }
data List a = Nil | Cons a (List a)

build :: Int -> List P
build n = if n == 0 then Nil else Cons (P { a = n }) (build (n - 1))

loop :: List P %1 -> Int
loop xs = case xs of
  Nil -> 0
  Cons y ys -> loop (build (a y - 1))

main :: Int
main = loop (build 3)
