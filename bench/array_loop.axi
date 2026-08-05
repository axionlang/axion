-- Array sequential benchmark: 50M elements, fill via loop then sum.
-- All operations are direct calls (no imperative block needed).

fill :: Int -> Int -> Int -> Int
fill a i n = if i == n then a
  else let a2 = setArray a i i in fill a2 (i + 1) n

sumArr :: Int -> Int -> Int -> Int -> Int
sumArr a i n acc = if i == n then acc
  else sumArr a (i + 1) n (acc + getArray a i)

main :: Int
main = let a = newArray 50000000 0 in
       let a = fill a 0 50000000 in
       sumArr a 0 50000000 0
