-- A monomorphic `head`-like function returns an extracted heap element on one
-- path and a fresh value on the other. Its `List Box` param stays borrowed: the
-- element is copied on its path, so the caller frees both the list and the result
-- once each (an uncopied element was a double-free on native). All backends agree
-- on 5 (the returned element's value); no crash.
data Box = Box Int

firstBox :: List Box -> Box
firstBox xs = case xs of
  Nil -> Box 0
  Cons b rest -> b

main :: Int
main = case firstBox (Cons (Box 5) (Cons (Box 6) Nil)) of
  Box n -> n
