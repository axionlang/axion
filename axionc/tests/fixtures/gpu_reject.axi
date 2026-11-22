-- Every gpuFor here is refused (docs/gpu.md): a GPU kernel computes with Int, Float and Bool
-- values and reads the arrays it captures (AX0802), and like any parallel kernel it has no
-- effects (AX0800) and is written out where the loop is (AX0801).

data Shape = Circle Int | Square Int

area :: Shape -> Int
area s = case s of
  Circle r -> 3 * r * r
  Square a -> a * a

label :: Int -> Int
label i = strLen (showInt i)

applyTo :: (Int -> Int) -> Array Int -> Array Int
applyTo f a = gpuFor a (\i x -> f x)

-- AX0802: a data value, through a function
shapes :: Array Int -> Array Int
shapes a = gpuFor a (\i x -> area (Circle x))

-- AX0802: a String, two calls away
labels :: Array Int -> Array Int
labels a = gpuFor a (\i x -> label x + 1)

-- AX0802: a tuple
pairs :: Array Int -> Array Int
pairs a = gpuFor a (\i x -> case (i, x) of
  (p, q) -> p + q)

-- AX0800: an effect
noisy :: Array Int -> Array Int
noisy a = gpuFor a (\i x -> let u = putStrLn "x" in x)

-- AX0801: no kernel to check
withKernel :: ((Int -> Int -> Int) -> Array Int) -> Array Int
withKernel run = run (\i x -> x + i)

partial :: Array Int -> Array Int
partial a = withKernel (gpuFor a)

main :: IO ()
main = putStrLn "unreachable"
