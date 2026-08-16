-- `tritvec` kernel (§10): ternary-quantized dot product over a base-243 packed
-- TritVec, built the FAST way — `tritVecIota` packs 5 trits/byte in one native
-- pass (no per-trit read-modify-write), `arrayIota` fills the activations in one
-- pass, and `tritDot` fuses the reduce. Weights stay packed (10 MB); everything
-- Auto-Dropped once. C and Rust do the same bulk-pack + fused MAC.
-- weight(i)=(i mod 3)-1, a[i]=i, N=50M — identical result across all variants.
main :: Int
main = tritDot (tritVecIota 50000000) (arrayIota 50000000)
