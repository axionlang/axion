-- Integer refinements (`refine.rs`, docs/refinements.md): each call proves its refined
-- arguments from what is known where it is made; a refined result is proven at each return and
-- known after each call. Array accesses the checker proves in bounds compile without their
-- check (`fill`'s `setArray`, `search`'s `getArray`, `get`'s `getArray`).

get :: a:Array Int -> {i:Int | 0 <= i && i < len a} -> Int
get a i = getArray a i

-- fill a i: element j becomes 3*j, from i to the end
fill :: a:Array Int -> {i:Int | 0 <= i && i <= len a} -> Array Int
fill a i = if i >= lenArray a then a else fill (setArray a i (i * 3)) (i + 1)

-- the first index in [lo, hi) whose element is >= x (the array is sorted)
search :: a:Array Int -> Int -> {lo:Int | 0 <= lo} -> {hi:Int | lo <= hi && hi <= len a} -> {r:Int | lo <= r && r <= hi}
search a x lo hi =
  if lo >= hi then lo
  else
    let mid = lo + (hi - lo) / 2 in
    if getArray a mid < x then search a x (mid + 1) hi else search a x lo mid

sumFrom :: a:Array Int -> {i:Int | 0 <= i} -> Int -> Int
sumFrom a i acc = if i < lenArray a then sumFrom a (i + 1) (acc + get a i) else acc

clamp :: Int -> {hi:Int | 0 <= hi} -> {r:Int | 0 <= r && r <= hi}
clamp x hi
  | x < 0 = 0
  | x > hi = hi
  | otherwise = x

-- a guard proves the access; without it this would not compile
safeGet :: Array Int -> Int -> Int
safeGet a i = if 0 <= i && i < lenArray a then get a i else 0 - 1

-- a refined result is a fact at the call: `clamp`'s result indexes the array directly
pick :: a:Array Int -> Int -> Int
pick a k = if lenArray a > 0 then get a (clamp k (lenArray a - 1)) else 0

main :: IO ()
main = do
  let arr = fill (newArray 10 0) 0
  putStrLn (showInt (search arr 9 0 (lenArray arr)))
  putStrLn (showInt (search arr 10 0 (lenArray arr)))
  putStrLn (showInt (search arr 100 0 (lenArray arr)))
  putStrLn (showInt (sumFrom arr 0 0))
  putStrLn (showInt (safeGet arr 4 + safeGet arr 12))
  putStrLn (showInt (pick arr 50 + pick arr (0 - 5)))
