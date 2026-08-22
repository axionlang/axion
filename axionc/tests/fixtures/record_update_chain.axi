-- Record-update reclamation, CHAINED: `b1` updates `xs`, then `b2` updates `ys` of `b1`.
-- Each result owns exactly the field it last updated and aliases the rest, so ownership
-- of `xs` and `ys` ends up split across b0/b1/b2 — every heap list must be freed exactly
-- once. `b2` is the only one read (its owned `ys` + its aliased `xs`), so b0/b1 die as
-- dead update chains. Exercises the skip-destructor across a chain of by-copy updates.
--   lenX b2 = 2 (aliased from b1), lenY b2 = 3 (owned by b2)  →  5
data Box = Box { xs :: List Int, ys :: List Int }

lenX :: Box -> Int
lenX b = length (xs b)

lenY :: Box -> Int
lenY b = length (ys b)

main :: Int
main =
  let b0 = Box { xs = Cons 1 Nil, ys = Cons 2 Nil }
      b1 = b0 { xs = Cons 3 (Cons 3 Nil) }
      b2 = b1 { ys = Cons 4 (Cons 4 (Cons 4 Nil)) }
  in lenX b2 + lenY b2
