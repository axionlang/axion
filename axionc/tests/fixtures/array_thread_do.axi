-- Same as array_thread_let but via the `imperative do` desugaring (a <- …), whose
-- single-var `case` binds are collapsed to substitutions so the threaded array is
-- reclaimed identically (no double-free from the aliased scrutinee). Sum 0..99 = 4950.
fill :: Array Int -> Int -> Int -> Array Int
fill a i n = if i == n then a else let a2 = setArray a i i in fill a2 (i + 1) n

sumArr :: Array Int -> Int -> Int -> Int -> Int
sumArr a i n acc = if i == n then acc else sumArr a (i + 1) n (acc + getArray a i)

main :: Int
main = imperative $ do
  a <- newArray 100 0
  a <- fill a 0 100
  sumArr a 0 100 0
