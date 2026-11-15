-- `delete`/`deleteBy`: remove the first matching element. VIEW functions (return the tail on a
-- match): they consume their list (`%1`) and free the removed element and the cells they
-- rebuild, so nothing leaks. delete 3 [1,3,5] = [1,5], sum = 6 on every backend.
main :: Int
main = sum (delete 3 (Cons 1 (Cons 3 (Cons 5 Nil))))
