-- Borrowed-argument reclamation (Auto-Drop §2): `dist` only reads the record's
-- fields (a pure borrow), so `main` — which allocates it — can free it after the
-- call instead of giving it up for lost. With AXION_HEAP_STATS=1 you count
-- 1 allocation and 1 free. dist(P 3 4) = 3 + 4 = 7.
data P = P { px :: Int, py :: Int }

dist :: P -> Int
dist p = px p + py p

main :: Int
main = dist (P { px = 3, py = 4 })
