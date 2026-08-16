-- `i32mv` kernel: int32 matvec — the compact-int32 (I32Array, 200 MB = 4 B/elem)
-- point between i8mv (50 MB) and dot_i8 (400 MB i64). Same matvec shape; shows the
-- memory→speed gradient across element widths. weight(i)=i, act(k)=k, N=50M, K=8192.
main :: Int
main = i32MatVecSum (i32Iota 50000000) (arrayIota 8192) 8192
