-- `maxOf` is generic over `Ord a`; specialized to Float at the use.
maxOf :: Ord a => a -> a -> a
maxOf x y = if x < y then y else x

main :: Float
main = maxOf 3.0 5.0 + maxOf 1.0 2.0
