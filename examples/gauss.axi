-- gauss.axi — a dense linear solver: Gaussian elimination with partial pivoting, solving Ax = b
-- for an N×N system over `Array Float` (the fourth flagship — numeric kernels, the surface
-- `pass`/`fff`/`lambda` don't reach: dense f64 arrays, nested index loops, in-place row operations).
--
-- Representation: the augmented matrix [A | b] is a single flat `Array Float` of size N·(N+1),
-- row-major (width W = N+1), so there is ONE linear resource to thread — not two. Every mutating
-- step (`setArray`) consumes and returns the handle; readers (`getArray`) borrow. The fixpoint
-- borrow analysis keeps the matrix owned by `main` and frees it exactly once (GC-free, race-free).
--
-- The no-GC cost is explicit and visible: no mutable aliasing, so each row operation threads the
-- array handle through a recursive loop (the `fill`/`sumArr` idiom from the Array fixtures, scaled
-- to a real algorithm). Pivoting makes it numerically honest, not a toy.
--
-- Test system (unique solution x = 2, y = 3, z = -1):
--     2x +  y -  z =   8
--    -3x -  y + 2z = -11
--    -2x +  y + 2z =  -3

-- flat index into the augmented matrix: row i, column j, width (N+1)
ix :: Int -> Int -> Int -> Int
ix n i j = i * (n + 1) + j

-- |x| for Float (no negative float literals / no built-in fabs: subtract from zero)
fabs :: Float -> Float
fabs x = if x <. 0.0 then 0.0 -. x else x

-- set one augmented-matrix cell (borrow-free handle threading)
put :: Array Float -> Int -> Int -> Int -> Float -> Array Float
put m n i j v = setArray m (ix n i j) v

-- the row (>= k) with the largest |M[row][k]| — the partial pivot
argmaxCol :: Array Float -> Int -> Int -> Int -> Int -> Int
argmaxCol m n k i best =
  if i >= n then best
  else
    let cur = fabs (getArray m (ix n i k)) in
    let bst = fabs (getArray m (ix n best k)) in
    let best2 = if cur >. bst then i else best in
    argmaxCol m n k (i + 1) best2

-- swap rows r1 and r2 across all W = n+1 columns (j = 0 .. n inclusive)
swapRow :: Array Float -> Int -> Int -> Int -> Int -> Array Float
swapRow m n r1 r2 j =
  if j > n then m
  else
    let v1 = getArray m (ix n r1 j) in
    let v2 = getArray m (ix n r2 j) in
    let m1 = setArray m (ix n r1 j) v2 in
    let m2 = setArray m1 (ix n r2 j) v1 in
    swapRow m2 n r1 r2 (j + 1)

-- eliminate one row i against pivot row k: M[i][j] -= factor * M[k][j], j = k .. n
elimRow :: Array Float -> Int -> Int -> Int -> Int -> Float -> Array Float
elimRow m n k i j factor =
  if j > n then m
  else
    let mij = getArray m (ix n i j) in
    let mkj = getArray m (ix n k j) in
    let m1 = setArray m (ix n i j) (mij -. (factor *. mkj)) in
    elimRow m1 n k i (j + 1) factor

-- eliminate every row below the pivot k (rows i = k+1 .. n-1)
elimBelow :: Array Float -> Int -> Int -> Int -> Array Float
elimBelow m n k i =
  if i >= n then m
  else
    let factor = (getArray m (ix n i k)) /. (getArray m (ix n k k)) in
    let m1 = elimRow m n k i k factor in
    elimBelow m1 n k (i + 1)

-- forward elimination over pivot columns k = 0 .. n-1 (pivot, then eliminate below)
forward :: Array Float -> Int -> Int -> Array Float
forward m n k =
  if k >= n then m
  else
    let p = argmaxCol m n k k k in
    let m1 = swapRow m n k p 0 in
    let m2 = elimBelow m1 n k (k + 1) in
    forward m2 n (k + 1)

-- sum_{j=i+1 .. n-1} M[i][j] * x[j] (the already-solved tail during back-substitution)
rowSum :: Array Float -> Array Float -> Int -> Int -> Int -> Float -> Float
rowSum m x n i j acc =
  if j >= n then acc
  else
    let term = (getArray m (ix n i j)) *. (getArray x j) in
    rowSum m x n i (j + 1) (acc +. term)

-- back-substitution: x[i] = (M[i][n] - sum_{j>i} M[i][j]·x[j]) / M[i][i], for i = n-1 .. 0.
-- Borrows the (now upper-triangular) matrix; consumes and returns the solution vector.
backsub :: Array Float -> Array Float -> Int -> Int -> Array Float
backsub m x n i =
  if i < 0 then x
  else
    let s = (getArray m (ix n i n)) -. (rowSum m x n i (i + 1) 0.0) in
    let xi = s /. (getArray m (ix n i i)) in
    let x2 = setArray x i xi in
    backsub m x2 n (i - 1)

-- build the augmented matrix for the test system (row-major, width n+1)
build :: Int -> Array Float
build n =
  let m = newArray (n * (n + 1)) 0.0 in
  let m = put m n 0 0 2.0 in
  let m = put m n 0 1 1.0 in
  let m = put m n 0 2 (0.0 -. 1.0) in
  let m = put m n 0 3 8.0 in
  let m = put m n 1 0 (0.0 -. 3.0) in
  let m = put m n 1 1 (0.0 -. 1.0) in
  let m = put m n 1 2 2.0 in
  let m = put m n 1 3 (0.0 -. 11.0) in
  let m = put m n 2 0 (0.0 -. 2.0) in
  let m = put m n 2 1 1.0 in
  let m = put m n 2 2 2.0 in
  put m n 2 3 (0.0 -. 3.0)

-- print the solution vector, one component per line (borrows x)
printSol :: Array Float -> Int -> Int -> IO ()
printSol x n i =
  if i >= n then putStr ""
  else do
    putStrLn (showFloat (getArray x i))
    printSol x n (i + 1)

-- residual ‖Ax − b‖²: over the ORIGINAL augmented matrix `a`, sum (A[i]·x − b[i])² across rows.
-- `rowSum a x n i 0 0.0` is the full dot A[i]·x (cols 0 .. n-1); column n holds b[i]. A second
-- matvec — self-validation that the in-place elimination actually solved the system.
resid :: Array Float -> Array Float -> Int -> Int -> Float -> Float
resid a x n i acc =
  if i >= n then acc
  else
    let d = (rowSum a x n i 0 0.0) -. (getArray a (ix n i n)) in
    resid a x n (i + 1) (acc +. (d *. d))

verdict :: Float -> String
verdict r = if r <. 0.000001 then "ok" else "FAIL"

-- borrow the original matrix `a` and the solution `x`: print the solution, then the verdict
report :: Array Float -> Array Float -> Int -> IO ()
report a x n = do
  printSol x n 0
  putStrLn (verdict (resid a x n 0 0.0))

main :: IO ()
main =
  let n = 3 in
  let m = forward (build n) n 0 in
  let x = backsub m (newArray n 0.0) n (n - 1) in
  report (build n) x n
