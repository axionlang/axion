-- Must FAIL with AX0001: the INDIRECT contractions the parameter check missed.
-- `Two xs xs` was caught, but a heap value could be laundered past the check and
-- DOUBLE-FREED natively through a `let` alias, a `where` alias, a `case` field
-- binder, a guarded body, or a call returning a heap value. A heap value may be
-- READ freely but MOVED into an owned position only once; sharing by ownership
-- needs `split` into %0.5 halves (§2).
data Box = Box Int
data V = Vn | Vc Box V
data T = T V V

idv :: V -> V
idv v = v

-- (1) `let` ALIAS of a borrowed heap value, moved into two owned slots.
mkLet :: V -> T
mkLet xs = let z = xs in T z z

-- (2) `case`-EXTRACTED heap field binder (the tail `ys`), moved twice.
mkCase :: V -> T
mkCase xs = case xs of
  Vn -> T Vn Vn
  Vc y ys -> T (Vc y ys) (Vc y ys)

-- (3) `where` ALIAS.
mkWhere :: V -> T
mkWhere xs = T z z where z = xs

-- (4) guarded body over a `where` alias.
mkGuard :: V -> T
mkGuard xs
  | otherwise = T z z
  where z = xs

-- (5) `let` bound to a heap-returning CALL (top-level).
mkCall :: V -> T
mkCall xs = let z = idv xs in T z z

-- (6) `let` bound to a heap-returning WHERE-LOCAL (projection) — the module-level
-- return-type table doesn't see locals, so this laundered past the check before.
mkLocal :: V -> T
mkLocal xs = let z = loc xs in T z z
  where loc v = v
