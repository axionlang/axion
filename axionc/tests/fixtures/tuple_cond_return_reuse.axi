-- Regression lock: the R-5 TUPLE deep-copier closes the conditional-tuple-param-return reuse
-- double-free (the P3 residual). `pickT` returns its tuple param `t` WHOLE on the else branch
-- (a `ret_alias`) while freeing a fresh tuple on the then branch; `go` then consumes BOTH the
-- returned value (which aliased `t`) AND `t` itself (`useT t`). Before the tuple copier, the
-- reuse-gated copy in `normalize_alias_returns` WANTED to fire (pickT's param ∈ ret_alias ∩
-- reused) but a tuple had no `CopyKind` → it silently failed-closed, so `t`'s one storage was
-- freed twice: verify said "clean" and every native backend aborted with "double free detected".
-- Now `gen_copiers` emits `axion_copy_tuple$String$String` (one implicit constructor, heap slots
-- at i*8, shell-copy + per-slot fixup — mirrors `gen_tuple_destructors`), so `ret t` becomes
-- `ret axion_copy_tuple$String$String t`: pickT always returns a FRESH owned tuple, `_t0` and `t`
-- are distinct storage, each freed once. interp == cranelift == llvm = "pqpq"; ASan + LSan clean.
useT :: (String, String) -> String
useT t = case t of
  (a, b) -> strAppend a b

pickT :: Int -> (String, String) -> (String, String)
pickT c t = if c > 0 then ("x", "y") else t

go :: (String, String) -> String
go t = strAppend (useT (pickT 0 t)) (useT t)

main :: IO ()
main = putStrLn (go (strAppend "p" "", strAppend "q" ""))
