-- Build and consume a List whose ELEMENTS are heap (substr-built strings; nested
-- lists), then reclaim it. The specialized destructor (axion_drop_List$String /
-- axion_drop_List$List$Int) now deep-drops the elements — axion_str_drop for a
-- String slot, the inner destructor for a nested list — so it is LEAK-FREE, not
-- just corruption-free. interp == cranelift == llvm (all print 25).
sumStrLens :: List String -> Int
sumStrLens xs = case xs of
  Nil -> 0
  Cons y ys -> strLen y + sumStrLens ys

sumAll :: List (List Int) -> Int
sumAll xs = case xs of
  Nil -> 0
  Cons y ys -> sum y + sumAll ys

main :: Int
main = sumStrLens (words "alpha beta gamma delta") + sumAll (Cons (Cons 1 (Cons 2 Nil)) (Cons (Cons 3 Nil) Nil))
