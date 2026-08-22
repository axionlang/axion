-- Must FAIL (AX0001): aliasing a heap value into two owned positions. A record
-- constructor takes OWNERSHIP of its field (deep-dropped with the record), so
-- storing `x` in two records consumes it twice — native deep-drop would then
-- double-free it. The linearity checker rejects the contraction (covering uses in
-- sibling `let` bindings, and `Many` fields, not just the body).
data W = W (List Int)

lenW :: W -> Int
lenW w = case w of
  W xs -> length xs

main :: Int
main =
  let x = Cons 1 (Cons 2 (Cons 3 Nil))
      a = W x
      b = W x
  in lenW a + lenW b
