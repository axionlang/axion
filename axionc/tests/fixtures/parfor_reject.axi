-- Every parFor here is refused (docs/parallel.md): a kernel runs on several threads at once,
-- in no fixed order, so it may only compute.

logged :: Int -> Int
logged x = let u = putStrLn "x" in x

viaLogged :: Int -> Int
viaLogged x = logged x + 1

-- AX0800: an effect in the kernel itself
direct :: Array Int -> Array Int
direct a = parFor a (\i x -> let u = putStrLn "hi" in x)

-- AX0800: an effect two calls away
indirect :: Array Int -> Array Int
indirect a = parFor a (\i x -> viaLogged x)

-- AX0800: a named kernel with an effect
noisy :: Int -> Int -> Int
noisy i x = logged x

named :: Array Int -> Array Int
named a = parFor a noisy

-- AX0800: writing a captured array in place
writeCap :: Array Int -> Array Int -> Array Int
writeCap cap a = parFor a (\i x -> getArray (setArray cap 0 i) 0)

-- AX0800: exiting
quits :: Array Int -> Array Int
quits a = parFor a (\i x -> if x < 0 then exitWith 1 else x)

-- AX0801: no kernel to check
withKernel :: ((Int -> Int -> Int) -> Array Int) -> Array Int
withKernel run = run (\i x -> x + i)

usesPartial :: Array Int -> Array Int
usesPartial a = withKernel (parFor a)

main :: IO ()
main = putStrLn "unreachable"
