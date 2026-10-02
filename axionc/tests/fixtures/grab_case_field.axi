-- Regression lock: a record-field GETTER that extracts a heap field via `case` and returns it
-- BARE is a pure interior alias of its (borrowed) argument — the CASE-extraction twin of
-- `field_alias_return.axi`'s `grab w = inner w` (which uses a FIELD accessor op). Before the
-- grab-via-case fix, the verifier's pure-alias summary ran with field-tracking OFF, so it could
-- not see that `getName r`'s result IS `r`'s field `a`; it classified the bare-field return as a
-- fresh OWNED String and recorded no alias. Auto-Drop then inserted a `drop` on EACH `getName r`
-- call result — and because `useBoth` calls it twice over the SAME borrowed `r`, both drops freed
-- the one field `a` → a verifier-BLIND double-free (verify said "clean", every native backend
-- aborted with "double free detected"). The fix promotes a bare case-extracted-field return of a
-- BORROWED scrutinee into the PURE summary (`verify::compute_summaries`, gated on `ret_is_bare_var`
-- so an EMBED like `take`'s `Cons y ys` stays in the ELEM/AX0912 relation), so the regions pass
-- nulls the call's ownership: `_t0`/`_t1` are borrows, never dropped, and `main`'s deep-drop of the
-- `R` frees field `a` exactly once. interp == cranelift == llvm = "foofoo"; ASan + LSan clean.
data R = R String String

getName :: R -> String
getName r = case r of
  R a b -> a

useBoth :: R -> String
useBoth r = strAppend (getName r) (getName r)

sample :: R
sample = R (strAppend "foo" "") (strAppend "bar" "")

main :: IO ()
main = putStrLn (useBoth sample)
