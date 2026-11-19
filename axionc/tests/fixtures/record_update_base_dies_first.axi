-- A by-copy record update `b1 = b0 { xs = … }` SHARES b0's `ys` with b1; skip-destructors make
-- exactly one side free it. That side must be the one freed LAST: here b0 dies first (its last
-- use is `lenXs b0`) while b1 still reads the shared `ys` — so b0 must skip `ys` and b1 free it.
-- Auto-Drop used to always make the dropped RESULT skip, freeing `ys` with b0 and leaving b1 a
-- dangling `ys` (a use-after-free that ASan could not see: the generated code was not
-- instrumented). The verifier now models the sharing within a function and refuses the old order.
--   lenXs b0 = 2, lenYs b1 = 3, lenXs b1 = 4  →  9
data Box = Box { xs :: List Int, ys :: List Int }

lenXs :: Box -> Int
lenXs b = length (xs b)

lenYs :: Box -> Int
lenYs b = length (ys b)

main :: Int
main =
  let b0 = Box { xs = Cons 1 (Cons 2 Nil), ys = Cons 3 (Cons 4 (Cons 5 Nil)) }
      b1 = b0 { xs = Cons 7 (Cons 8 (Cons 9 (Cons 10 Nil))) }
  in lenXs b0 + lenYs b1 + lenXs b1
