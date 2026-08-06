-- Array threaded through helper functions (§A): `fill` owns the array (%1-style,
-- consumes via setArray and returns it), `sumArr` BORROWS it (read-only getArray
-- loop, recursive). The fixpoint borrow analysis (compute_borrow_args) classifies
-- sumArr's param as a borrow so main keeps ownership and frees the array exactly
-- once after the traversal. Shadowed `a` is disambiguated by the uniquify pass.
-- build 0..99 in place, sum = 99*100/2 = 4950. 1 array alloc == 1 free.
fill :: Array Int -> Int -> Int -> Array Int
fill a i n = if i == n then a else let a2 = setArray a i i in fill a2 (i + 1) n

sumArr :: Array Int -> Int -> Int -> Int -> Int
sumArr a i n acc = if i == n then acc else sumArr a (i + 1) n (acc + getArray a i)

main :: Int
main = let a = newArray 100 0 in let a = fill a 0 100 in sumArr a 0 100 0
