-- A constructor whose type keeps a variable nothing in the program constrains
-- (`Left s :: Either String b`, `Just (Left s)`) got no destructor key, so its cell and payload
-- were never freed natively. Such a variable has no values, so it now defaults to `Int` and the
-- cell is keyed (`Either$String$Int`) and freed. A generic function's own type variables are
-- left alone. Same result on every backend, ASan + LSan clean.
data Box a b = Box a (List b)

main :: Int
main =
  let a = Left (showInt 123)
      b = Just (Left (showInt 45))
      c = Box (strAppend "x" "y") Nil
  in (case a of
       Left s -> strLen s
       Right _ -> 0)
     + (case b of
          Just e -> (case e of
                       Left s -> strLen s
                       Right _ -> 0)
          Nothing -> 0)
     + (case c of
          Box s rest -> strLen s + length rest)
