-- dense Array (§A Phase 2): linear ownership + auto-drop.
-- newArray produces a linear resource; setArray consumes it (in-place
-- mutation) and returns a new handle. The array is automatically freed
-- at the end of its scope via axion_array_free. Expected: 150.
main :: Int
main = imperative $ do
  a <- newArray 5 0
  a <- setArray a 0 10
  a <- setArray a 1 20
  a <- setArray a 2 30
  a <- setArray a 3 40
  a <- setArray a 4 50
  (getArray a 0) + (getArray a 1) + (getArray a 2) + (getArray a 3) + (getArray a 4)
