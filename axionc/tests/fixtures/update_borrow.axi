-- Reclaiming the base of a copy-update (Auto-Drop §2): `shiftX` borrows the
-- record (reads the fields to allocate a copy with `x` changed, does not retain it),
-- so `main` — which allocates it — frees it after the call. No `show`/IO, so the
-- result is a pure Int (no runtime string) and LSan can prove 0 leaks.
-- shiftX (Point 1 2) = Point 99 2;  sum of both records' fields = (1+2)+(99+2) = 104.
data Point = Point { x :: Int, y :: Int }

sumP :: Point -> Int
sumP p = x p + y p

shiftX :: Point -> Point
shiftX p = p { x = 99 }

main :: Int
main =
  let p0 = Point { x = 1, y = 2 } in
  let p1 = shiftX p0 in
  sumP p0 + sumP p1
