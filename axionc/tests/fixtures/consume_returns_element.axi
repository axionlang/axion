-- A monomorphic `head`-like function returns an extracted heap element. Its
-- `List Box` param is inferred `%1` so the caller does NOT free the returned
-- element (which aliases the list) — previously a double-free on native. All
-- backends agree on 5 (the returned element's value); no crash.
data Box = Box Int

firstBox :: List Box -> Box
firstBox xs = case xs of
  Nil -> Box 0
  Cons b rest -> b

main :: Int
main = case firstBox (Cons (Box 5) (Cons (Box 6) Nil)) of
  Box n -> n
