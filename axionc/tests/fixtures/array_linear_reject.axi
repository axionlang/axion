-- An array is a linear value (docs/array.md): `setArray` (and `parFor`, a function writing its
-- `Array` parameter) consumes it and hands back the array written in place. Each definition
-- here uses an array after giving it away, refused on every backend.

-- AX0001: the same array written twice
twice :: Int
twice =
  let cap = newArray 10 0 in
  let a = setArray cap 0 1 in
  let b = setArray cap 0 2 in
  getArray a 0 + getArray b 0

-- AX0004: the array read after it was written in place
stale :: Int
stale =
  let cap = newArray 10 0 in
  let a = setArray cap 0 1 in
  getArray cap 0 + getArray a 0

-- AX0001: through a function that writes its parameter (so it owns it)
bump :: Array Int -> Int -> Array Int
bump a i = setArray a 0 i

viaHelper :: Int
viaHelper =
  let cap = newArray 10 0 in
  let x = bump cap 1 in
  let y = bump cap 2 in
  getArray x 0 + getArray y 0

main :: IO ()
main = putStrLn "unreachable"
