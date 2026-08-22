-- A `data` type holding a field whose type has HEAP ELEMENTS (a List of
-- substr-built strings). Its generated destructor now keys the field on its MONO
-- destructor (`axion_drop_List$String`), which deep-drops the elements — the
-- head-only `axion_drop_List` froze the spine and leaked them. Leak-free now.
-- interp == cranelift == llvm (all print 10).
data Box = Box { items :: List String, tag :: Int }

sizeBox :: Box -> Int
sizeBox b = length (items b) + tag b

main :: Int
main =
  let b = Box { items = words "alpha beta gamma", tag = 7 }
  in sizeBox b
