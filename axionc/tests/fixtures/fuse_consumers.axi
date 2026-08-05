-- Regression fixture for the `--fuse` stream-fusion pass. Covers every fused
-- shape: `sum`/`length` (synthesized step closures), `foldr` (user's closure
-- passed through — the fused call must NOT synthesize `+`), and `null`
-- (nil base `True`, step `False` — an empty range must still read as `True`).
-- The two `null` calls differ in the range: empty → 7, non-empty → 0.
-- Expected: 66 + 11 + 720 + 7 + 0 = 804 (fused == unfused, all backends).
main :: Int
main =
  let a = sum (range 1 11)
      c = length (range 1 11)
      g = foldr (\x acc -> x * acc) 1 (range 1 6)
      h = if null (range 1 0) then 7 else 0
      i = if null (range 1 1) then 7 else 0
  in a + c + g + h + i
