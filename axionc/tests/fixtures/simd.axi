-- SIMD vector types (docs/simd.md): arithmetic, lanes, sums, min/max, fma, sqrt, range-checked
-- loads/stores, vectors as parameters/results/loop state and through if/case joins, a polymorphic
-- function used at Int and at a vector. All three backends agree.
axpy :: Float -> F64x4 -> F64x4 -> F64x4
axpy a x y = fmaF64x4 (splatF64x4 a) x y

dotLoop :: Array Float -> Array Float -> Int -> Int -> F64x4 -> Float
dotLoop xs ys i n acc =
  if i + 4 <= n
    then dotLoop xs ys (i + 4) n (acc + loadF64x4 xs i * loadF64x4 ys i)
    else sumF64x4 acc

fill :: Array Float -> Int -> Int -> Array Float
fill a i n = if i < n then fill (setArray a i (toFloat i)) (i + 1) n else a

scaleAll :: Array Float -> Int -> Int -> Array Float
scaleAll a i n =
  if i + 4 <= n
    then scaleAll (storeF64x4 a i (loadF64x4 a i * splatF64x4 2.0)) (i + 4) n
    else a

ints :: I64x4
ints = i64x4 1 2 3 4 * splatI64x4 10 - i64x4 0 1 2 3

mainA :: IO ()
mainA = do
  let v = f64x4 1.0 2.0 3.0 4.0
  let w = axpy 0.5 v (splatF64x4 1.0)
  putStrLn (showFloat (sumF64x4 w))
  putStrLn (showFloat (laneF64x4 w 3))
  putStrLn (showFloat (sumF64x4 (minF64x4 v (splatF64x4 2.5))))
  putStrLn (showFloat (sumF64x4 (sqrtF64x4 (v * v))))
  putStrLn (showInt (sumI64x4 ints))
  putStrLn (showInt (laneI64x4 (maxI64x4 ints (splatI64x4 25)) 1))
  let xs = fill (newArray 16 0.0) 0 16
  let ys = scaleAll (fill (newArray 16 0.0) 0 16) 0 16
  putStrLn (showFloat (dotLoop xs ys 0 16 (splatF64x4 0.0)))
  putStrLn (showFloat (sumF64x2 (f64x2 0.25 0.5 / f64x2 0.5 0.25)))
  putStrLn (showInt (laneI64x2 (i64x2 7 9) 1))

data Op = Add | Mul | Neg

step :: Op -> I64x4 -> I64x4 -> I64x4
step op a b = case op of
  Add -> a + b
  Mul -> a * b
  Neg -> splatI64x4 0 - a

go :: Int -> I64x4 -> I64x4
go n acc = if n == 0 then acc else go (n - 1) (step (if n `mod` 3 == 0 then Mul else if n `mod` 3 == 1 then Add else Neg) acc (i64x4 1 2 3 n))


pick :: Bool -> a -> a -> a
pick b x y = if b then x else y


main :: IO ()
main = do
  mainA
  putStrLn (showInt (sumI64x4 (go 20 (i64x4 1 1 1 1)) + laneI64x4 (go 7 (splatI64x4 3)) 2))
  putStrLn (showInt (pick True 3 4 + truncate (sumF64x2 (pick False (splatF64x2 1.0) (splatF64x2 2.0)))))
