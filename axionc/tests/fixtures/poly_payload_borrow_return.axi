-- Regression (§2): a deep drop of an owned parametric scrutinee must NOT fire
-- when the arm returns a value that could ALIAS the scrutinee's payload. Here the
-- arm returns `inner y` — a heap sub-object BORROWED out of the payload `y`. A
-- deep drop (`axion_drop_List$P`, which frees `y` and its `inner`) would then
-- free the very pointer being returned → double-free (interp disagreeing with the
-- crashing native backends). Auto-Drop detects the heap-typed result and falls
-- back to a SHALLOW scrutinee free (safe; the untouched tail leaks — the deferred
-- extracted-field gap). All three executors must agree: z (inner of head) = 3.
data Inner = Inner { z :: Int }
data P = P { inner :: Inner }
data List a = Nil | Cons a (List a)

build :: Int -> List P
build n = if n == 0 then Nil else Cons (P { inner = Inner { z = n } }) (build (n - 1))

firstInner :: List P %1 -> Inner
firstInner xs = case xs of
  Nil -> Inner { z = 0 }
  Cons y ys -> inner y

main :: Int
main = z (firstInner (build 3))
