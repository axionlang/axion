-- User-defined symbolic operators. A parenthesized operator names a plain
-- function; used infix, `a <+> b` lowers to `(<+>) a b` (the backtick-infix
-- path), so every backend handles it. An operator is also first-class as `(<+>)`.
(<+>) :: Int -> Int -> Int
(<+>) a b = a + a + b

(|>) :: Int -> (Int -> Int) -> Int
(|>) x f = f x

double :: Int -> Int
double n = n * 2

applyOp :: (Int -> Int -> Int) -> Int -> Int -> Int
applyOp f a b = f a b

main :: Int
main =
  let s = 3 <+> 4 <+> 5      -- left-assoc: ((3<+>4)<+>5) = (10<+>5) = 25
      t = 10 |> double        -- 20
  in applyOp (<+>) s t        -- (<+>) as a value: (<+>) 25 20 = 25+25+20 = 70
