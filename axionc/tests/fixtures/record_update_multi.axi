-- Record-update reclamation, MULTI-FIELD: updating two non-adjacent heap fields
-- (`b`, `d`) leaves a MULTI-ELEMENT skip set {0,2} (the non-updated `a`, `c`). The
-- skip-destructor name is order-sensitive (gen_skip_destructors sorts; the codegen/llvm
-- emitters don't), so the indices must be sorted — this fixture is the one that stresses
-- a >1-element skip (existing F-3 skips are all ≤1). `q0` deep-drops all four of its
-- lists; `q1` reclaims only its owned updated `b`,`d` and skips the aliased `a`,`c`.
--   lenA q0 = 1, lenA q1 = 1  →  2
data Q = Q { a :: List Int, b :: List Int, c :: List Int, d :: List Int }

lenA :: Q -> Int
lenA q = length (a q)

main :: Int
main =
  let q0 = Q { a = Cons 1 Nil, b = Cons 2 (Cons 2 Nil), c = Cons 3 Nil, d = Cons 4 (Cons 4 Nil) }
      q1 = q0 { b = Cons 9 (Cons 9 (Cons 9 Nil)), d = Cons 7 Nil }
  in lenA q0 + lenA q1
