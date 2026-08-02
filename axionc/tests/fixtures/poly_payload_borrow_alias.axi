-- Payload-alias tracking (§2): the arm reads a HEAP sub-object out of the owned
-- scrutinee's payload (`inner y`) and passes it to a tail call (`useInner (inner
-- y)`). That value ALIASES into `y`, which the deep drop of the scrutinee frees —
-- so the drop must be placed AFTER the call (bind-then-drop), not before it, even
-- though the call is in tail position. The alias analysis marks `inner y` as
-- payload-aliasing and forbids the TCO drop-before here (unlike `a y :: Int`,
-- which is a scalar copy). Result is a scalar, so a deep drop still fires and
-- reclaims the whole list. build 3 → 9 objects, all reclaimed; z of head = 3.
data Inner = Inner { z :: Int }
data P = P { inner :: Inner }
data List a = Nil | Cons a (List a)

build :: Int -> List P
build n = if n == 0 then Nil else Cons (P { inner = Inner { z = n } }) (build (n - 1))

useInner :: Inner -> Int
useInner i = z i

sumZ :: List P %1 -> Int
sumZ xs = case xs of
  Nil -> 0
  Cons y ys -> useInner (inner y)

main :: Int
main = sumZ (build 3)
