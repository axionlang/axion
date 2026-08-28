-- Left-fold accumulator over a `%1` list: `addI z y` BORROWS the accumulator `z` and the
-- element `y` (a fresh-returning bignum add), then the recursion threads a NEW accumulator —
-- so both `z` and `y` are borrowed-then-dead each step and must be reclaimed (the foldl
-- Route-C-loss: a specialized/direct call borrows what `callclo` would have moved). `z` escapes
-- on the Nil arm (returned) but dies on Cons; `y` dies after the borrow. All intermediates freed.
addI :: Integer -> Integer -> Integer
addI a b = a + b
foldlI :: Integer -> List Integer %1 -> Integer
foldlI z xs = case xs of
  Nil -> z
  Cons y ys -> foldlI (addI z y) ys
main :: IO ()
main = putStrLn (showInteger (foldlI (fromInt 0)
  (Cons (1000000000000 + 1) (Cons (2000000000000 + 2) (Cons (3000000000000 + 3) Nil)))))
