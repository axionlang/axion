-- `ternmv` kernel (§10): the REALISTIC ternary matvec (BitNet inner loop). M×K
-- packed weights (tritVecIota, 10 MB) against a SMALL reused K-activation
-- (arrayIota, K=8192, cache-resident) — only the 10 MB packed weights stream, so
-- packing's footprint becomes a SPEED win (vs a 50 MB int8 weight array). One
-- fused primitive, borrows both, both Auto-Dropped once. weight(i)=(i mod 3)-1,
-- act(k)=k, N=50M, K=8192 — identical result across Axion / C / Rust.
main :: Int
main = tritMatVecSum (tritVecIota 50000000) (arrayIota 8192) 8192
