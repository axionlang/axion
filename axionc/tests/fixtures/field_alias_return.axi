-- Regions/lifetimes: a function may RETURN A BORROW of a parameter — an interior heap
-- pointer into it, not a fresh allocation. `grab w = inner w` hands back `w`'s `inner`
-- field. The compiler infers this is a borrow-returning function (its result is, on every
-- path, a pure interior alias of a param) and nulls the ownership of every call to it, so
-- the caller does NOT free the result: the argument's owner (`main`, which built the `W`)
-- frees it exactly once via the record's deep-drop. Both `inner` and `other` are reclaimed;
-- no leak, no double free. Before regions this was the last undefended class — a caller
-- freeing the borrow while the owner's drop freed the same field (the drop-balance verifier
-- flagged it; now the lowering makes it sound and the verifier confirms). Result: 2.
data W = W { inner :: List Int, other :: List Int }

grab :: W -> List Int
grab w = inner w

useW :: W -> Int
useW w = length (grab w)

main :: Int
main = useW (W { inner = Cons 1 (Cons 2 Nil), other = Cons 9 Nil })
