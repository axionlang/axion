-- `take` over a HEAP element type (Integer). It keeps a prefix of its input into a fresh output
-- list; while its list param was BORROWED, those kept elements aliased the shared input into the
-- owned result → a native double-free (the AX0912 alias-borrower class). The prelude now marks
-- `take`'s list param `%1`, so it CONSUMES the list: each kept element is a genuine move and the
-- discarded tail (the `else Nil` cutoff) is freed — no alias, no double-free. It compiles and
-- runs identically to the interpreter on every backend, ASan + LSan clean. Sum of 1+2+3 = 6.
addI :: Integer -> Integer -> Integer
addI a b = a + b
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (take 3 (map fromInt (range 1 5)))))
