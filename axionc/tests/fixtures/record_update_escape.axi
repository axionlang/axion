-- Record-update reclamation, ESCAPING result (base dead). `b1 = b0 { xs = … }`
-- shallow-copies, so `b1.ys` aliases `b0.ys`. `b1` then ESCAPES into a list (`Cons b1
-- Nil`), whose generic destructor deep-drops it — freeing the shared `ys`. If `b0` also
-- deep-dropped `ys`, that's a DOUBLE FREE (regression fixture: it did, on native, before
-- the escape-aware fix). The fix hands ownership of the shared fields to the escaped
-- result and drops the BASE via a skip-destructor (frees only the updated field's OLD
-- value + shell, skips `ys`). Leak-free, no double free.
--   firstLen [b1] = length [3,3,3] + length [2,2] = 3 + 2 = 5
data Box = Box { xs :: List Int, ys :: List Int }

firstLen :: List Box -> Int
firstLen bs = case bs of
  Nil -> 0
  Cons b rest -> lenBox b + lenRest rest

lenBox :: Box -> Int
lenBox b = case b of
  Box p q -> length p + length q

lenRest :: List Box -> Int
lenRest bs = case bs of
  Nil -> 0
  Cons b rest -> lenBox b + lenRest rest

main :: Int
main =
  let b0 = Box { xs = Cons 1 Nil, ys = Cons 2 (Cons 2 Nil) }
      b1 = b0 { xs = Cons 3 (Cons 3 (Cons 3 Nil)) }
      lst = Cons b1 Nil
  in firstLen lst
