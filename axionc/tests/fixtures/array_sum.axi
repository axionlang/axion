-- dense Array: packed, mutable i64 arrays with O(1) random access.
-- Builds a 5-element array [10,20,30,40,50], reads each element, sums them.
-- Expected: 150.  0 allocs (raw i64 buffer, not Cons cells).
main :: Int
main = imperative $ do
  a <- newArray 5 0
  a <- setArray a 0 10
  a <- setArray a 1 20
  a <- setArray a 2 30
  a <- setArray a 3 40
  a <- setArray a 4 50
  (getArray a 0) + (getArray a 1) + (getArray a 2) + (getArray a 3) + (getArray a 4)
