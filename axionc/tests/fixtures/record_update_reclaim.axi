-- Reclaiming the RESULT of a by-copy record update (Auto-Drop §2). `b1 = b0 { xs = … }`
-- shallow-copies: `b1.xs` is a genuinely-owned NEW list, but `b1.ys` ALIASES `b0.ys`.
-- Deep-dropping `b1` wholesale would double-free the shared `ys`; flat-dropping it (the
-- old behavior) leaked the new `xs`. The fix drops `b1` via a skip-destructor that frees
-- only the updated slot (`xs`) and skips the aliased one (`ys`) — leak-free, no double
-- free. `b0` is deep-dropped normally (it owns both its lists). `lenXs` borrows.
--   lenXs b0 = 2, lenXs b1 = 4  →  6
data Box = Box { xs :: List Int, ys :: List Int }

lenXs :: Box -> Int
lenXs b = length (xs b)

main :: Int
main =
  let b0 = Box { xs = Cons 1 (Cons 2 Nil), ys = Cons 3 (Cons 4 (Cons 5 Nil)) }
      b1 = b0 { xs = Cons 7 (Cons 8 (Cons 9 (Cons 10 Nil))) }
  in lenXs b0 + lenXs b1
