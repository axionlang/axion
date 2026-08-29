-- Regions §move-out (tuple case-extraction): the tuple twin of case_extract_escape.
-- A function that case-extracts an element of a FRESH LOCAL tuple and returns it.
-- The tuple is shell-freed (its extracted element is moved out, the other is a
-- non-heap Nil) — this shape was already sound (shell-free of the tuple cell keeps
-- the moved-out element alive); locked in as a companion to the `data` case.
grabFst :: Int -> List Int
grabFst n = case (Cons n Nil, Nil) of
  (a, b) -> a

main :: Int
main = length (grabFst 7)
