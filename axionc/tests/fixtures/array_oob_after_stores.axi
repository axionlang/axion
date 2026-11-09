-- A write loop that runs one slot past the end must still abort at exactly index 5, with the real
-- length. Guards the TBAA split of the Array length slot from its elements (llvm.rs): LLVM may now
-- keep `len` in a register across the element stores, so a store must never be able to change it.
fill :: Array Int -> Int -> Int -> Array Int
fill a i n = if i == n then a else let a2 = setArray a i 7 in fill a2 (i + 1) n

main :: Int
main = getArray (fill (newArray 5 0) 0 6) 0
