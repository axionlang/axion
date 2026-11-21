-- REJECT (AX0100): or-patterns are allowed only in a `case` arm, not a clause parameter.
f :: Maybe Int -> Int
f (Just 1 | Nothing) = 1
f _ = 0

main :: Int
main = f Nothing
