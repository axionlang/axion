-- Deep-drop of a nested polymorphic container (poly-drop Phase 4). `map (range 1)`
-- builds a `List (List Int)` with DISTINCT inner lists ([1], [1,2], [1,2,3]); the
-- outer `map sum`/`sum` consume it and it is dropped in `main`. Before Phase 4 the
-- generic `axion_drop_List` freed only the spine (the 6 inner-list cells leaked);
-- now the drop is keyed at the concrete type `List$List$Int`, so the specialized
-- destructor reclaims the elements too — 17 allocs / 17 frees, ASan/LSan-clean.
-- Result = sum [1, 3, 6] = 10.
main :: Int
main = sum (map sum (map (range 1) (range 1 3)))
