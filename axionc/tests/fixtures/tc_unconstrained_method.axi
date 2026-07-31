-- AX0405: polymorphic use of a method without declaring the constraint in the signature.
bad :: a -> Bool
bad x = eq x x

main :: Bool
main = bad 3
