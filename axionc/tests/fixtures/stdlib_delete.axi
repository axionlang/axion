-- `delete`/`deleteBy`: remove the first matching element. VIEW functions (return the tail on a
-- match), auto-moved via `returns_var_directly` (core.rs) — sound (no double-free), but the
-- removed prefix leaks conservatively like `drop`/`dropWhile`, so this is in the CORRUPTION gate
-- (ASan), not the leak-free gate. delete 3 [1,3,5] = [1,5], sum = 6 on every backend.
main :: Int
main = sum (delete 3 (Cons 1 (Cons 3 (Cons 5 Nil))))
