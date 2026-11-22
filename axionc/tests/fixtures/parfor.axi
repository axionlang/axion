-- Parallel loops: `parFor a k` replaces every element `i` of `a` by `k i a[i]`, the indices
-- split among threads (docs/parallel.md). The result is the same on every backend and with
-- any number of threads.
{-# TOTAL scale #-}

-- a matrix (row-major, n x n) times a vector: one row per element of the result
matVec :: Array Float -> Array Float -> Int -> Array Float
matVec m v n = parFor (newArray n 0.0) (\r _ -> dotRow m v n r 0 0.0)

dotRow :: Array Float -> Array Float -> Int -> Int -> Int -> Float -> Float
dotRow m v n r j acc =
  if j >= n then acc else dotRow m v n r (j + 1) (acc +. getArray m (r * n + j) *. getArray v j)

-- uneven work per element: the blocks are shared out as threads finish
collatz :: Int -> Int -> Int
collatz n steps =
  if n <= 1 then steps
  else if n `mod` 2 == 0 then collatz (n / 2) (steps + 1)
  else collatz (3 * n + 1) (steps + 1)

-- a named kernel reading the old element
bump :: Int -> Int -> Int
bump i x = x * 2 + i

-- a total function may use parFor: its kernel is checked with it
scale :: Array Int -> Array Int
scale a = parFor a (\_ x -> x * 3)

-- a kernel calling a function passed in
tabulate :: Int -> (Int -> Int) -> Array Int
tabulate n f = parFor (newArray n 0) (\i _ -> f i)

-- a parFor inside a kernel runs on that kernel's thread
triangle :: Int -> Int
triangle r = sumA (parFor (newArray (r + 1) 0) (\j _ -> j)) 0 0

sumA :: Array Int -> Int -> Int -> Int
sumA a i acc = if i >= lenArray a then acc else sumA a (i + 1) (acc + getArray a i)

sumF :: Array Float -> Int -> Float -> Float
sumF a i acc = if i >= lenArray a then acc else sumF a (i + 1) (acc +. getArray a i)

countTrue :: Array Bool -> Int -> Int -> Int
countTrue a i acc =
  if i >= lenArray a then acc else countTrue a (i + 1) (if getArray a i then acc + 1 else acc)

main :: IO ()
main = do
  let n = 120
  let m = parFor (newArray (n * n) 0.0) (\k _ -> toFloat (k `mod` 7) -. 3.0)
  let v = parFor (newArray n 0.0) (\j _ -> toFloat j *. 0.5)
  putStrLn (showFloat (sumF (matVec m v n) 0 0.0))
  putStrLn (showInt (sumA (parFor (newArray 20000 0) (\i _ -> collatz (i + 1) 0)) 0 0))
  putStrLn (showInt (sumA (scale (parFor (arrayIota 1000) bump)) 0 0))
  let k = 7
  putStrLn (showInt (sumA (tabulate 500 (\i -> i * k)) 0 0))
  putStrLn (showInt (sumA (parFor (newArray 300 0) (\r _ -> triangle r)) 0 0))
  putStrLn (showInt (countTrue (parFor (newArray 1000 False) (\i _ -> i `mod` 3 == 0)) 0 0))
