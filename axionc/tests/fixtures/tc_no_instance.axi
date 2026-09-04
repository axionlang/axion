-- AX0404: method over a concrete type with no instance (Foo has no Eq).
data Foo = Foo
main :: Bool
main = eq Foo Foo
