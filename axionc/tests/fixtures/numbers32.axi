-- 32-bit numbers (docs/numbers32.md): `Int32` wraps at 32 bits and `Float32` rounds to single
-- precision once per operation, the same on every backend.

-- a linear congruential generator: the wrapping is the point
lcg :: Int32 -> Int32 -> Int32
lcg x k = if k <= 0 then x else lcg (x * 1103515245 + 12345) (k - 1)

-- a sum in single precision (the order matters: each step is rounded to a single)
harmonic :: Float32 -> Int32 -> Float32
harmonic acc n = if n <= 0 then acc else harmonic (acc + 1.0 / int32ToFloat32 n) (n - 1)

-- `div`/`mod` truncate as for `Int`, and `minBound / -1` wraps
quot32 :: Int32 -> Int32 -> Int32
quot32 a b = a `div` b

rem32 :: Int32 -> Int32 -> Int32
rem32 a b = a `mod` b

big :: Int32
big = 2000000000

f32 :: Float32 -> Float32
f32 x = x

norm :: Float32 -> Float32 -> Float32
norm x y = sqrtF32 (x * x + y * y)

sumF :: Array Float32 -> Int -> Float32 -> Float32
sumF a i acc = if i >= lenArray a then acc else sumF a (i + 1) (acc + getArray a i)

-- a single-precision kernel run on every core: no fused multiply-add, the same bits
orbit :: Float32 -> Float32 -> Float32 -> Float32 -> Int32 -> Int32
orbit cr ci zr zi k =
  if k >= 200 then k
  else if zr * zr + zi * zi > 4.0 then k
  else orbit cr ci (zr * zr - zi * zi + cr) (2.0 * zr * zi + ci) (k + 1)

sumA :: Array Int -> Int -> Int -> Int
sumA a i acc = if i >= lenArray a then acc else sumA a (i + 1) (acc + getArray a i)

main :: IO ()
main = do
  putStrLn (show (big + big))
  putStrLn (show (lcg 1 100))
  putStrLn (show (quot32 (0 - 7) 2) ++ " " ++ show (rem32 (0 - 7) 2))
  putStrLn (show (quot32 (0 - 2147483647 - 1) (0 - 1)) ++ " " ++ show (rem32 (0 - 2147483647 - 1) (0 - 1)))
  putStrLn (show (toInt32 4294967301) ++ " " ++ show (fromInt32 big * 2))
  putStrLn (show (f32 0.1) ++ " " ++ showFloat (fromFloat32 (f32 0.1)))
  putStrLn (show (harmonic 0.0 1000))
  putStrLn (show (norm 3.0 4.0) ++ " " ++ show (sqrtF32 2.0))
  putStrLn (show (truncateF32 (f32 1.0e10)) ++ " " ++ show (truncateF32 (f32 0.0 / 0.0)) ++ " " ++ show (truncateF32 (0.0 - 2.75)))
  putStrLn (show (f32 1.5 < 2.5) ++ " " ++ show (f32 1.5 >= 2.5) ++ " " ++ show (f32 0.0 / 0.0 == f32 0.0 / 0.0))
  let v = parFor (newArray 1000 0.0) (\i _ -> int32ToFloat32 (toInt32 i) * 0.001)
  putStrLn (show (sumF v 0 0.0))
  let w = 256
  let m = parFor (newArray (w * w) 0) (\p _ -> fromInt32 (orbit (int32ToFloat32 (toInt32 (p `mod` w)) * 3.0 / int32ToFloat32 (toInt32 w) - 2.0) (int32ToFloat32 (toInt32 (p / w)) * 3.0 / int32ToFloat32 (toInt32 w) - 1.5) 0.0 0.0 0))
  putStrLn (showInt (sumA m 0 0))
