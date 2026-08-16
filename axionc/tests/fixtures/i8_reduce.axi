-- I8Array reductions: i8Sum(i8Iota 10)= sum (i mod 3)-1 = -1; i8Dot against
-- arrayIota = sum ((i mod 3)-1)*i = -3.  -1*100 + -3 = -103.
main :: Int
main = (i8Sum (i8Iota 10)) * 100 + (i8Dot (i8Iota 10) (arrayIota 10))
