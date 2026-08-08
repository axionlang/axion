-- A MONOMORPHIC list-transforming function that reuses heap elements in its result
-- (`appendBox` puts `xs`'s `Box` elements into the returned list). Its `List Box`
-- param is inferred `%1` (consumed) — otherwise it is treated as a borrow, the
-- caller deep-drops the input, and the shared elements are freed twice (double-free
-- on native). With the fix it OWNS the input: the spine is freed, the elements move
-- into the result. build (2+1 elems) → 3 Box + 3 Cons(orig) + 2 Cons(new) = 8
-- allocs, all freed; sum = 1+2+3 = 6.
data Box = Box Int

appendBox :: List Box -> List Box -> List Box
appendBox xs ys = case xs of
  Nil -> ys
  Cons z zs -> Cons z (appendBox zs ys)

sumB :: List Box -> Int
sumB xs = case xs of
  Nil -> 0
  Cons y ys -> case y of Box n -> n + sumB ys

main :: Int
main = sumB (appendBox (Cons (Box 1) (Cons (Box 2) Nil)) (Cons (Box 3) Nil))
