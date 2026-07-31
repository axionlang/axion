-- AX0404: method over a concrete type with no instance (there is no Eq String).
main :: Bool
main = eq "a" "b"
