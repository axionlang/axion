-- parMap with a HEAP reply payload (§9), reclaimed exactly (poly-drop Phase 4).
-- Each worker replies with a `List Int` (`range 1 n`), so parMap's result is a
-- `List (List Int)`. The result is dropped in `main` keyed at its concrete type
-- (`List$List$Int`, resolved from inference in `collect_drop_types`), so the
-- specialized destructor reclaims the inner reply lists too — AXION_HEAP_STATS
-- shows 25 allocs / 25 frees (was 25/10 before the element type was threaded).
-- Value: sum of each reply = 15, times 3 = 45. ASan/LSan-clean on all backends.
worker :: Ep (Recv Int (Send (List Int) End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (range 1 n)
  close d3

main :: Int
main = sum (map sum (parMap worker (replicate 3 5)))
