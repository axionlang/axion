-- Bulk builders (spec §10): tritVecIota packs weight(i)=(i mod 3)-1 five trits/byte
-- in one native pass (no per-trit read-modify-write); arrayIota fills a[i]=i in one
-- pass. Both return fresh owned resources, Auto-Dropped once. tritDot borrows both.
--
-- 10 trits: weight(i) = -1,0,+1,…; a[i] = i.  w*i: 0,0,2,-3,0,5,-6,0,8,-9 → sum = -3.
main :: Int
main = tritDot (tritVecIota 10) (arrayIota 10)
