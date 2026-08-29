-- Conditional-discard reclamation: `keepBig` (filter's shape) MOVES the kept element into
-- `Cons y …` on one branch but DISCARDS it on the else. The discarded heap element must be
-- freed on the else path — the branch-sensitive `reclaim_cond_escape` element discovery
-- (`go`'s borrow-only liveness cannot, it would drop `y` before its move). Every bignum
-- allocated is reclaimed: no leak, corruption-free. sum of the two > big = 5000000000005.
big :: Integer
big = 1000000000000
keepBig :: List Integer %1 -> List Integer
keepBig xs = case xs of
  Nil -> Nil
  Cons y ys -> if y > big then Cons y (keepBig ys) else keepBig ys
sumL :: List Integer %1 -> Integer
sumL xs = case xs of
  Nil -> fromInt 0
  Cons y ys -> y + sumL ys
main :: IO ()
main = putStrLn (showInteger (sumL (keepBig
  (Cons (2000000000000 + 2) (Cons (fromInt 5) (Cons (3000000000000 + 3) Nil))))))
