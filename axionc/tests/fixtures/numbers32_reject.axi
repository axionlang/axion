-- 32-bit numbers (docs/numbers32.md): each definition here is refused.

-- AX0200: a literal that does not fit
tooBig :: Int32
tooBig = 3000000000

-- AX0200: an Int32 and an Int do not mix (convert with toInt32 / fromInt32)
mixed :: Int32 -> Int -> Int32
mixed a b = a + b

-- AX0200: a Float32 literal is written with a point
whole :: Float32
whole = 1

-- AX0404: `div` is integer division
fdiv :: Float32 -> Float32 -> Float32
fdiv a b = a `div` b

main :: IO ()
main = putStrLn "unreachable"
