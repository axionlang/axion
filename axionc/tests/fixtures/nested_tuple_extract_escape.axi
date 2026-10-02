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
-- FIX: when the tuple mono-key is unsegmentable AND a field is mentioned (so it may escape),
-- shell-free the OUTER cell only — the escaping field survives and any non-escaping heap siblings
-- LEAK (sound — the documented nested-tuple-in-tuple residual; a leak, never a double-free). A
-- dead-discard nested tuple (no field mentioned) still deep-drops, so no needless leak.
--
-- interp == cranelift == llvm = "p"; ASan clean (NO double-free / UAF). NOTE: a conservative
-- residual leak of the unsegmentable sibling remains (outside the LEAKFREE gate) until tuple mono
-- keys encode their arity. The SOUNDNESS win — the UAF is gone — is what this fixture locks.
useNT :: ((String, String), (String, String)) -> String
useNT t = case t of
  (a, b) -> case a of
    (x, y) -> x

main :: IO ()
main = putStrLn (useNT ((strAppend "p" "", "q"), ("r", "s")))
