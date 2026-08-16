-- Ternary matvec (spec §10): tritMatVecSum sums dot(row, act) over all rows of an
-- M×K packed weight vector against a SMALL reused K-activation — the BitNet inner
-- loop, streaming only the packed weights. Borrows both; both Auto-Dropped once.
--
-- N=10 trits, K=4: weight(i)=(i mod 3)-1, act(k)=k → sum_i weight(i)*act(i mod 4).
--   i:      0  1  2  3  4  5  6  7  8  9
--   w:     -1  0  1 -1  0  1 -1  0  1 -1
--   act[i%4]:0  1  2  3  0  1  2  3  0  1
--   w*act:  0  0  2 -3  0  1 -2  0  0 -1  → -3
main :: Int
main = tritMatVecSum (tritVecIota 10) (arrayIota 4) 4
