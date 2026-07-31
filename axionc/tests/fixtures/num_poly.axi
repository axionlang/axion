-- `sq` is generic over `Num a`; specialized to Int and Float at the uses.
sq :: Num a => a -> a
sq x = x * x

main :: Float
main = sq 3.0 + sq 2.0
