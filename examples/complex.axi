-- complex.axi — user-defined numeric types, the payoff of `Num`/`Division` being real
-- typeclasses rather than hardcoded operators. `Complex` is an ordinary `data` type; declaring
-- `instance Num Complex` / `instance Division Complex` makes `+ - * /` work on it directly, with
-- the same syntax as the built-in numeric types. (Float fields → scalar, no heap.)
data Complex = Complex Float Float

reC :: Complex -> Float
reC c = case c of Complex r i -> r
imC :: Complex -> Float
imC c = case c of Complex r i -> i

addC :: Complex -> Complex -> Complex
addC a b = Complex (reC a +. reC b) (imC a +. imC b)

subC :: Complex -> Complex -> Complex
subC a b = Complex (reC a -. reC b) (imC a -. imC b)

-- (a+bi)(c+di) = (ac - bd) + (ad + bc)i
mulC :: Complex -> Complex -> Complex
mulC a b = Complex
  (reC a *. reC b -. imC a *. imC b)
  (reC a *. imC b +. imC a *. reC b)

-- (a+bi)/(c+di) = ((ac+bd) + (bc-ad)i) / (c² + d²)
divC :: Complex -> Complex -> Complex
divC a b = let d = reC b *. reC b +. imC b *. imC b in
  Complex
    ((reC a *. reC b +. imC a *. imC b) /. d)
    ((imC a *. reC b -. reC a *. imC b) /. d)

instance Num Complex where
  (+) a b = addC a b
  (-) a b = subC a b
  (*) a b = mulC a b
  fromInteger n = Complex (toFloat n) 0.0

instance Division Complex where
  (/) a b = divC a b

showC :: Complex -> String
showC c = strAppend (showFloat (reC c)) (strAppend " + " (strAppend (showFloat (imC c)) "i"))

main :: IO ()
main = do
  putStrLn (showC (Complex 1.0 2.0 + Complex 3.0 4.0))   -- 4 + 6i
  putStrLn (showC (Complex 5.0 6.0 - Complex 1.0 2.0))   -- 4 + 4i
  putStrLn (showC (Complex 1.0 2.0 * Complex 3.0 4.0))   -- -5 + 10i
  putStrLn (showC (Complex 1.0 0.0 / Complex 2.0 0.0))   -- 0.5 + 0i
