-- Polymorphic-payload reclamation (§2): a generic container `List a` holding a
-- HEAP element (`List P`, `P` a record) must free its payloads when dropped. A
-- generic `axion_drop_List` cannot (the element field `a` is a type variable, and
-- an i64 is indistinguishable pointer-vs-Int at runtime), so a MONOMORPHIZED
-- destructor `axion_drop_List$P` is generated per concrete instantiation: it frees
-- the element via `P` and recurses on the tail via `axion_drop_List$P`.
--
-- `firstOr` owns the list (`%1`), BORROWS the head payload (`a y`) and ignores the
-- tail — so the whole list is deep-dropped. The scrutinee drop is placed AFTER the
-- body (past the borrow of `y`), not at the head, or it would be a use-after-free.
-- build 3 → 3 Cons cells + 3 P records = 6 allocs; all 6 freed; head payload = 3.
data P = P { a :: Int }
data List a = Nil | Cons a (List a)

build :: Int -> List P
build n = if n == 0 then Nil else Cons (P { a = n }) (build (n - 1))

firstOr :: List P %1 -> Int
firstOr xs = case xs of
  Nil -> 0
  Cons y ys -> a y

main :: Int
main = firstOr (build 3)
