-- Clause-form functions bind patterns as `let a = _p1`. That alias must not make a read-only param
-- look consumed: `sumK` borrows, so `main` keeps `a`, reads it again and frees it once (it used to
-- leak, or be rejected with a false AX0910). `idArr` returns its param through the same alias, so it
-- must stay a MOVE: borrowing it would double-free. 15 + 3 + 3 = 21.
sumK :: Int -> Array Int -> Int
sumK 0 a = 0
sumK k a = getArray a 0 + sumK (k - 1) a

idArr :: Int -> Array Int -> Array Int
idArr 0 a = a
idArr k a = idArr (k - 1) a

main :: Int
main =
  let a = newArray 4 3 in
  let x = sumK 5 a in
  let y = getArray a 1 in
  let b = idArr 2 a in
  x + y + getArray b 2
