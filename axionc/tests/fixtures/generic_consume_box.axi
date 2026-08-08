-- Generic list-transformers (`append`/`reverse`/`concat`) on a HEAP-element list
-- (`List Box`). Each reuses/returns extracted `Box` elements in its result, so it
-- must CONSUME (own) its list — else the caller deep-drops the input and the shared
-- elements are double-freed on native. Consume-inference marks their `List a` param
-- `%1` (pure-escape) and the owning-generic native exclusion is lifted (they only
-- shell-free the spine). reverse [1,2] = [2,1]; concat [[3]] = [3];
-- append [2,1] [3] = [2,1,3]; sum = 6. All three backends agree, leak-free.
data Box = Box Int

val :: Box -> Int
val b = case b of Box n -> n

sumB :: List Box -> Int
sumB xs = case xs of
  Nil -> 0
  Cons y ys -> val y + sumB ys

main :: Int
main = sumB (append (reverse (Cons (Box 1) (Cons (Box 2) Nil)))
                    (concat (Cons (Cons (Box 3) Nil) Nil)))
