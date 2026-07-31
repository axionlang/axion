-- Cross-function reclamation (Auto-Drop §2, linear). 'make' allocates a Box and
-- returns it (the caller now owns it); 'take' receives it by %1 (ownership moved)
-- and frees it at its death point. main = take (make 42) → 42, with 1 alloc == 1
-- free (the object crosses the boundary and is freed once).
data Box = Box { val :: Int }

make :: Int -> Box
make n = Box { val = n }

take :: Box %1 -> Int
take b = val b

main :: Int
main = take (make 42)
