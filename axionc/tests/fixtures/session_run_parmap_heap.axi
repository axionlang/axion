-- parMap with a HEAP reply payload (§9) — documents the deep-drop LIMITATION.
-- Each worker replies with a `List Int` (`range 1 n`), so parMap's result is a
-- `List (List Int)`. The COMPUTED VALUE is correct on all three executors
-- (sum of each reply = 15, times 3 = 45), but reclamation is only PARTIAL: the
-- outer list and the input list are freed, while the inner reply lists leak,
-- because parMap keys its result as the generic flat `axion_drop_List` (cons cells
-- only), not a per-element deep drop. Concretely: AXION_HEAP_STATS shows 25 allocs
-- / 10 frees here (the 3 × 5 = 15 inner-list cells leak).
--
-- Scalar replies (Int/Float — the common case, see session_run_parmap.axi) reclaim
-- EXACTLY. The fix, deferred until a heap-returning worker needs it, is to key the
-- result at its concrete element type and reuse the `axion_drop_List$T`
-- mono-destructor. See docs/by-example.md §11b and the Op::drop_ty comment in core.rs.
worker :: Ep (Recv Int (Send (List Int) End)) %1 -> IO ()
worker d = do
  (n, d2) <- recv d
  d3 <- send d2 (range 1 n)
  close d3

main :: Int
main = sum (map sum (parMap worker (replicate 3 5)))
