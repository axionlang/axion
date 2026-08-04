-- Polymorphic-payload extracted-field gap: a generic-owning function
-- `dropList :: List a %1 -> Int` that recursively consumes the list.
-- In the `Cons y ys -> dropList ys` arm, the tail `ys` is transferred
-- while the head `y` stays with the record.  Today the scrutinee is
-- shallow-freed → the head's payload leaks.
-- With the fix, the remainder (non-transferred head + shell) is reclaimed.
-- Expected (after fix): 3 Cons + 3 P = 6 allocs, all freed.

data P = P { x :: Int }
data List a = Nil | Cons a (List a)

dropList :: List a %1 -> Int
dropList xs = case xs of
  Nil -> 0
  Cons y ys -> dropList ys

main :: Int
main = dropList (Cons (P { x = 1 }) (Cons (P { x = 2 }) (Cons (P { x = 3 }) Nil)))
