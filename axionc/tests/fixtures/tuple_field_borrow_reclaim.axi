-- Borrowed-then-dead TUPLE fields with a HEAP result: `sndSum t = case t of (a,b) -> a + b`
-- over `(Integer, Integer)` reads BOTH bignum fields (borrows) then discards them, returning a
-- FRESH Integer. Because the result is heap the tuple takes the non-deep (shell-free) scrut
-- drop, so the fields must be reclaimed by the tuple notion-2 pass (`go` drops a/b AFTER the
-- add) — else they leak (the getFst tuple-consume leak, 144 B). Every bignum is reclaimed.
big :: Integer
big = 1000000000000 + 1
sndSum :: (Integer, Integer) -> Integer
sndSum t = case t of
  (a, b) -> a + b
sumL :: List Integer %1 -> Integer
sumL xs = case xs of
  Nil -> fromInt 0
  Cons y ys -> y + sumL ys
main :: IO ()
main = putStrLn (showInteger (sumL (map sndSum (Cons (big, big) (Cons (big, big) Nil)))))
