-- A vector load past the end of the array aborts on every backend, naming the first bad index.
main :: Int
main = truncate (sumF64x4 (loadF64x4 (newArray 6 1.0) 3))
