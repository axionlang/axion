-- take is SPINE-DISCARDING (`else Nil` drops the whole tail), so it is NOT specializable and
-- stays generic + AX0912 even under AXION_SPECIALIZE: its kept elements alias the borrowed
-- input into the output → a native double-free over a heap element type. Interp runs it (12).
addI :: Integer -> Integer -> Integer
addI a b = a + b
main :: IO ()
main = putStrLn (showInteger (foldr addI 0 (take 3 (map fromInt (range 1 5)))))
