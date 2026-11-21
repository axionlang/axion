-- REJECT (AX0200): a variable bound by every alternative must have one type.
f :: Either Int String -> Int
f e = case e of
  Left x | Right x -> 1

main :: Int
main = f (Left 1)
