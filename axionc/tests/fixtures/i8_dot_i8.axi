-- i8DotI8 (Phase B / general): fair dense int8×int8 dot — both operands compact
-- I8Array (1 byte/elem). Borrows both (Auto-Dropped once). i8Iota 10 = weights
-- -1,0,1,… ; dot with itself = sum of squares = 7.
main :: Int
main = i8DotI8 (i8Iota 10) (i8Iota 10)
