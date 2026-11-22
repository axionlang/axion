-- GPU kernels (docs/gpu.md): `gpuFor a k` means what `parFor a k` means — element `i` becomes
-- `k i a[i]` — and under `--release` runs on the GPU when there is one. The output is the same on
-- every backend, on the GPU or not.
{-# TOTAL doubleAll #-}

-- a matrix (row-major, n x n) times a vector, one row per GPU thread
dotRow :: Array Float -> Array Float -> Int -> Int -> Int -> Float -> Float
dotRow m v n r j acc =
  if j >= n then acc else dotRow m v n r (j + 1) (acc +. getArray m (r * n + j) *. getArray v j)

-- integer work of uneven length per element
collatz :: Int -> Int -> Int
collatz n steps =
  if n <= 1 then steps
  else if n `mod` 2 == 0 then collatz (n / 2) (steps + 1)
  else collatz (3 * n + 1) (steps + 1)

-- a named kernel, with a `where`
mix :: Int -> Int -> Int
mix i x = x * 3 + h
  where h = (i * 7) `mod` 11

-- a total function may use gpuFor
doubleAll :: Array Int -> Array Int
doubleAll a = gpuFor a (\_ x -> x * 2)

-- a contract on a kernel's helper: proven at one call, checked on the device at the other
{-# CONTRACT pick requires 0 <= i && i < len a #-}
pick :: Array Int -> Int -> Int
pick a i = getArray a i

sumA :: Array Int -> Int -> Int -> Int
sumA a i acc = if i >= lenArray a then acc else sumA a (i + 1) (acc + getArray a i)

sumF :: Array Float -> Int -> Float -> Float
sumF a i acc = if i >= lenArray a then acc else sumF a (i + 1) (acc +. getArray a i)

countTrue :: Array Bool -> Int -> Int -> Int
countTrue a i acc =
  if i >= lenArray a then acc else countTrue a (i + 1) (if getArray a i then acc + 1 else acc)

main :: IO ()
main = do
  let n = 200
  let m = parFor (newArray (n * n) 0.0) (\k _ -> toFloat (k `mod` 9) -. 4.0)
  let v = parFor (newArray n 0.0) (\j _ -> toFloat j *. 0.25)
  putStrLn (showFloat (sumF (gpuFor (newArray n 0.0) (\r _ -> dotRow m v n r 0 0.0)) 0 0.0))
  putStrLn (showInt (sumA (gpuFor (newArray 100000 0) (\i _ -> collatz (i + 1) 0)) 0 0))
  putStrLn (showInt (sumA (doubleAll (gpuFor (arrayIota 1000) mix)) 0 0))
  let w = arrayIota 64
  let off = strLen "abc"
  putStrLn (showInt (sumA (gpuFor (newArray 64 0) (\i _ -> pick w i + pick w ((i + off) `mod` 64))) 0 0))
  putStrLn (showInt (countTrue (gpuFor (newArray 5000 False) (\i _ -> i `mod` 7 == 3)) 0 0))
  putStrLn (showInt (lenArray (gpuFor (newArray 0 0) (\i x -> x + i))))
  putStrLn (showInt (sumA (parFor (newArray 20 0) (\r _ -> sumA (gpuFor (newArray r 1) (\j x -> x + j)) 0 0)) 0 0))
