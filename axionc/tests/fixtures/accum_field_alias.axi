-- Regression (code-review finding #1): a heap accumulator that projects a FIELD ALIAS
-- of its owned param into the recursive value. `items acc` is an interior heap pointer
-- into `acc` that escapes (embedded in the new `Box` passed to the recursion). The
-- path-sensitive reclamation must NOT drop `acc` here — dropping it deep-frees `items acc`
-- while the escaped alias still uses it (a use-after-free before the fix). `acc` is kept
-- reclaimable only across bindings whose op returns a FRESH value. Since `acc` is not used
-- after `items acc`, the read is a MOVE-OUT: `drop acc : Box skip{items}` frees the shell and
-- the list lives on in the new `Box` (it used to leak the shells). ASan + LSan clean.
--   build 5 (Box Nil) grows a 5-element list → lenB = 5.
data Box = Box { items :: List Int }

build :: Int -> Box -> Box
build k acc =
  if k < 1
    then acc
    else build (k - 1) (Box { items = Cons k (items acc) })

lenB :: Box -> Int
lenB b = case b of
  Box xs -> length xs

main :: Int
main = lenB (build 5 (Box { items = Nil }))
