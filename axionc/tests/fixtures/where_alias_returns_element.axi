-- Safety guard: a `where`-local whose result ALIASES its argument (returns an
-- element of the borrowed list) must NOT be registered as a pure borrow — else the
-- parent would reclaim the list and free the returned element (double-free). The
-- heap result disqualifies it, so the value is conservatively left un-reclaimed
-- (safe). All backends must agree on 5 (no crash).
data Box = Box Int
data List a = Nil | Cons a (List a)

headBox :: List Box %1 -> Box
headBox xs = go xs
  where
    go ys = case ys of
      Nil -> Box 0
      Cons b rest -> b

main :: Int
main = case headBox (Cons (Box 5) (Cons (Box 6) Nil)) of
  Box n -> n
