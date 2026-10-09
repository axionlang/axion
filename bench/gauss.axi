-- Compute-bound numeric benchmark: dense Gaussian elimination with partial pivoting over
-- `Array Float`, solving an N×N system `reps` times. The matrix A is a FIXED diagonally-dominant
-- integer matrix; the true solution x varies per iteration (keeps the solver honest — no hoisting),
-- and b = A·x is recomputed each time. The result reduces to an INTEGER checksum (sum of the rounded
-- solution components over all solves), so stdout is a plain Int — bit-exact across backends and C,
-- independent of any last-ULP float-formatting difference. Measures f64 array throughput vs C.

ix :: Int -> Int -> Int -> Int
ix n i j = i * (n + 1) + j

fabs :: Float -> Float
fabs x = if x <. 0.0 then 0.0 -. x else x

-- fixed diagonally-dominant integer matrix: diagonal 4N dominates the off-diagonal row sum (≤ 3(N-1))
aEntry :: Int -> Int -> Int -> Float
aEntry n i j = if i == j then toFloat (4 * n) else toFloat (((i * 7 + j * 13) `mod` 3) + 1)

-- the true solution for this iteration (small positive integers 1..7, varying with iter)
xTrue :: Int -> Int -> Float
xTrue iter j = toFloat (((iter + j) `mod` 7) + 1)

-- b[i] = Σ_j A[i][j]·xTrue[j]
bRow :: Int -> Int -> Int -> Int -> Float -> Float
bRow n iter i j acc =
  if j >= n then acc
  else bRow n iter i (j + 1) (acc +. (aEntry n i j *. xTrue iter j))

-- fill row i of the augmented matrix: columns 0..n-1 = A, column n = b[i]
fillRow :: Array Float -> Int -> Int -> Int -> Int -> Array Float
fillRow m n iter i j =
  if j > n then m
  else
    let v = if j == n then bRow n iter i 0 0.0 else aEntry n i j in
    let m1 = setArray m (ix n i j) v in
    fillRow m1 n iter i (j + 1)

fillAug :: Array Float -> Int -> Int -> Int -> Array Float
fillAug m n iter i =
  if i >= n then m
  else let m1 = fillRow m n iter i 0 in fillAug m1 n iter (i + 1)

argmaxCol :: Array Float -> Int -> Int -> Int -> Int -> Int
argmaxCol m n k i best =
  if i >= n then best
  else
    let cur = fabs (getArray m (ix n i k)) in
    let bst = fabs (getArray m (ix n best k)) in
    let best2 = if cur >. bst then i else best in
    argmaxCol m n k (i + 1) best2

swapRow :: Array Float -> Int -> Int -> Int -> Int -> Array Float
swapRow m n r1 r2 j =
  if j > n then m
  else
    let v1 = getArray m (ix n r1 j) in
    let v2 = getArray m (ix n r2 j) in
    let m1 = setArray m (ix n r1 j) v2 in
    let m2 = setArray m1 (ix n r2 j) v1 in
    swapRow m2 n r1 r2 (j + 1)

elimRow :: Array Float -> Int -> Int -> Int -> Int -> Float -> Array Float
elimRow m n k i j factor =
  if j > n then m
  else
    let mij = getArray m (ix n i j) in
    let mkj = getArray m (ix n k j) in
    let m1 = setArray m (ix n i j) (mij -. (factor *. mkj)) in
    elimRow m1 n k i (j + 1) factor

elimBelow :: Array Float -> Int -> Int -> Int -> Array Float
elimBelow m n k i =
  if i >= n then m
  else
    let factor = (getArray m (ix n i k)) /. (getArray m (ix n k k)) in
    let m1 = elimRow m n k i k factor in
    elimBelow m1 n k (i + 1)

forward :: Array Float -> Int -> Int -> Array Float
forward m n k =
  if k >= n then m
  else
    let p = argmaxCol m n k k k in
    let m1 = swapRow m n k p 0 in
    let m2 = elimBelow m1 n k (k + 1) in
    forward m2 n (k + 1)

rowSum :: Array Float -> Array Float -> Int -> Int -> Int -> Float -> Float
rowSum m x n i j acc =
  if j >= n then acc
  else rowSum m x n i (j + 1) (acc +. ((getArray m (ix n i j)) *. (getArray x j)))

backsub :: Array Float -> Array Float -> Int -> Int -> Array Float
backsub m x n i =
  if i < 0 then x
  else
    let s = (getArray m (ix n i n)) -. (rowSum m x n i (i + 1) 0.0) in
    let xi = s /. (getArray m (ix n i i)) in
    let x2 = setArray x i xi in
    backsub m x2 n (i - 1)

-- round to nearest (solutions are near positive integers): truncate(v + 0.5)
roundI :: Float -> Int
roundI v = truncate (v +. 0.5)

checksum :: Array Float -> Int -> Int -> Int -> Int
checksum x n i acc =
  if i >= n then acc
  else checksum x n (i + 1) (acc + roundI (getArray x i))

solveOne :: Int -> Int -> Int
solveOne n iter =
  let aug = fillAug (newArray (n * (n + 1)) 0.0) n iter 0 in
  let m = forward aug n 0 in
  let x = backsub m (newArray n 0.0) n (n - 1) in
  checksum x n 0 0

solveLoop :: Int -> Int -> Int -> Int -> Int
solveLoop n iter reps acc =
  if iter >= reps then acc
  else solveLoop n (iter + 1) reps (acc + solveOne n iter)

main :: Int
main = solveLoop 64 0 1500 0
