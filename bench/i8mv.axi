-- `i8mv` kernel (Phase B): the int8 matvec baseline. M×K weights as a compact
-- I8Array (1 byte/elem = 50 MB, vs the old Array i64's 400 MB) against a small
-- reused K-activation. The dense counterpart of `ternmv` — 8× the weight traffic
-- of the packed vec, so it should trail `ternmv` but now match hand-written C int8.
-- weight(i)=(i mod 3)-1, act(k)=k, N=50M, K=8192 — identical result across variants.
main :: Int
main = i8MatVecSum (i8Iota 50000000) (arrayIota 8192) 8192
