-- Record-update reclamation, ESCAPING result while the base is still READ afterwards.
-- `b1 = b0 { xs = … }` (b1.ys aliases b0.ys); `b1` escapes into a list AND `b0` is read
-- after the update (`lenX b0`). Both `b0` and the escaped `b1` share `ys` — the base is
-- not dead, so ownership can't just move to `b1`; instead the base's drop skips the
-- shared fields (owned by the escaped result) and frees the updated field's OLD value.
-- This was ALSO a double free before the fix (base alive ≠ safe). Leak-free now.
--   lenX b0 = 1, firstX [b1] = 2  →  3
data Box = Box { xs :: List Int, ys :: List Int }

lenX :: Box -> Int
lenX b = length (xs b)

firstX :: List Box -> Int
firstX bs = case bs of
  Nil -> 0
  Cons h r -> lenX h

main :: Int
main =
  let b0 = Box { xs = Cons 1 Nil, ys = Cons 2 Nil }
      b1 = b0 { xs = Cons 3 (Cons 3 Nil) }
      lst = Cons b1 Nil
  in lenX b0 + firstX lst
