-- I32Array reductions: i32Dot(i32Iota 10, arrayIota 10)=sum i^2=285;
-- i32MatVecSum(i32Iota 10, arrayIota 4, 4)= sum i*(i mod 4)=61 → 346.
main :: Int
main = (i32Dot (i32Iota 10) (arrayIota 10)) + (i32MatVecSum (i32Iota 10) (arrayIota 4) 4)
