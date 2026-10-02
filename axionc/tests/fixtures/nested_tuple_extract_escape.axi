-- Regression lock (SOUNDNESS): a heap field of a NESTED-tuple scrutinee that ESCAPES into the
-- arm's heap result must not be freed by the scrutinee's deep-drop. `useNT t = case t of (a,b) ->
-- case a of (x,y) -> x` over `((String,String),(String,String))` previously lowered the outer
-- `drop t` as a FULL deep drop (its destructor — built from the TYPE via `drop_way`, which DOES
-- recurse into nested tuples — freed the inner tuple `a`), then the nested `case a` read freed `a`
-- → a verifier-BLIND use-after-free (verify said "clean"; every native backend aborted). The
-- CASE-ARM skip logic could not prevent it: a nested-tuple mono-key (`tuple$tuple$…`) is NOT
-- segmentable (`tuple_elem_drops` → None — inner arities aren't encoded in the key), so
-- `mentioned_slots` stayed empty and the skip set was empty.
--
-- FIX: tuple mono-keys now ENCODE THEIR ARITY (`tuple2$…`), so a nested-tuple key segments
-- unambiguously (`consume_one_key` reads N from `tupleN` and consumes exactly N sub-keys). The
-- case-arm skip-destructor path therefore resolves the inner element types, SKIPS the escaped
-- field, and deep-frees the remaining siblings precisely — no UAF and no leak. (The earlier
-- shell-free fallback for an unsegmentable key is retained as a belt-and-suspenders path, but
-- with arity-encoded keys it is no longer reached for a flat nested tuple.)
--
-- interp == cranelift == llvm = "p"; ASan + LSan clean — the escaping field survives, every
-- sibling is reclaimed. In the LEAKFREE gate.
useNT :: ((String, String), (String, String)) -> String
useNT t = case t of
  (a, b) -> case a of
    (x, y) -> x

main :: IO ()
main = putStrLn (useNT ((strAppend "p" "", "q"), ("r", "s")))
