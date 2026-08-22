-- Custom operator fixity. `<+>` is declared tighter than `<>`, and `<>` is
-- right-associative — so the grouping differs from the default (infixl 9 for both).
--   a = 1 <> 2 <+> 3  →  1 <> (2 <+> 3)  = 1 - (2+3)   = -4   (precedence)
--   b = 10 <> 3 <> 2  →  10 <> (3 <> 2)  = 10 - (3-2)  =  9    (right-assoc)
--   main = a + b = 5
-- With the default fixity (both infixl 9) this would be 2 + 5 = 7.
infixl 6 <+>
infixr 5 <>

(<+>) :: Int -> Int -> Int
(<+>) a b = a + b

(<>) :: Int -> Int -> Int
(<>) a b = a - b

main :: Int
main =
  let a = 1 <> 2 <+> 3
      b = 10 <> 3 <> 2
  in a + b
