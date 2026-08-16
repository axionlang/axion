-- TritVec (spec §10.B): base-243 packed balanced-ternary array — five trits per
-- byte (3^5 = 243). A trit is a WEIGHT -1/0/+1 (TMinus/TZero/TPlus) carried as Int.
-- Threaded through helpers like Array (docs/array.md): `fillTrit` OWNS the vec
-- (consumes via setTritVec, returns it), `sumTrit` BORROWS it (read-only
-- getTritVec recursion). The fixpoint borrow analysis keeps ownership in main so
-- the vec is auto-dropped (flat axion_free) exactly once — 1 alloc == 1 free.
--
-- Fill 99 trits with the repeating pattern (i mod 3) - 1 = -1,0,+1,… — 33 full
-- cycles summing to 0, proving pack→unpack is faithful across all byte boundaries.
fillTrit :: TritVec -> Int -> Int -> TritVec
fillTrit t i n = if i == n then t else let t2 = setTritVec t i ((i `mod` 3) - 1) in fillTrit t2 (i + 1) n

sumTrit :: TritVec -> Int -> Int -> Int -> Int
sumTrit t i n acc = if i == n then acc else sumTrit t (i + 1) n (acc + getTritVec t i)

main :: Int
main = let t = newTritVec 99 0 in let t = fillTrit t 0 99 in sumTrit t 0 99 0
