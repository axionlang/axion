-- Must FAIL with AX0600 (six times): calls whose refined arguments are not proven where they
-- are made. Each would index past the array, or rely on a fact that does not hold.

get :: a:Array Int -> {i:Int | 0 <= i && i < len a} -> Int
get a i = getArray a i

next :: {i:Int | 0 <= i} -> Int
next i = i

-- nothing is known about k
noFacts :: Array Int -> Int -> Int
noFacts a k = get a k

-- off by one: `i <= len a` allows `i == len a`
offByOne :: Array Int -> Int -> Int
offByOne a i = if 0 <= i && i <= lenArray a then get a i else 0

-- `k + 1` may wrap to a negative number when k is the largest Int
wraps :: Int -> Int
wraps k = if k >= 0 then next (k + 1) else 0

-- a Float comparison says nothing about the integer argument
floatFact :: Float -> Int -> Int
floatFact y k = if y > 0.0 then next k else 0

-- the fact is on the other branch
wrongBranch :: Int -> Int
wrongBranch k = if k < 0 then next k else 0

-- a refined result must hold on every return
neg :: Int -> {r:Int | 0 <= r}
neg x = if x > 0 then x else x

main :: IO ()
main = putStrLn (showInt (noFacts (newArray 3 0) 1))
