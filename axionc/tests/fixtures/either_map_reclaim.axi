-- Regression for a PRE-EXISTING multi-type-parameter reclamation double-free (core.rs
-- `cond_elem_key`, the `reclaim_cond_escape` path): mapping over `Right` while passing `Left`
-- through — `case e of Right y -> Right (f y); Left x -> Left x` — over a TWO-parameter sum
-- (`Either a b`). The field-drop-key was computed by a naive `split_once('$')` that took the
-- WHOLE tail of the mono key (`Either$Int$Int` → `Int$Int`) as the extracted element, so the
-- `Right` arm's SCALAR `Int` payload was dropped as a bogus `Int$Int` container = a bad free /
-- double-free on the native backends (interp reclaims via Rust `Drop`, so it — and the drop
-- verifier — silently passed). Fixed to resolve the field's own type PARAMETER first, like the
-- `consumed_elem_key` twin. Covers a scalar (Int) and a heap (String) `Left` payload.
mapRi :: Either Int Int -> Either Int Int
mapRi e = case e of
  Right y -> Right (y + 1)
  Left x -> Left x

mapRs :: Either String Int -> Either String Int
mapRs e = case e of
  Right y -> Right (y + 1)
  Left s -> Left s

showEi :: Either Int Int -> String
showEi e = case e of
  Left x -> strAppend "L" (showInt x)
  Right v -> strAppend "R" (showInt v)

showEs :: Either String Int -> String
showEs e = case e of
  Left s -> strAppend "L" s
  Right v -> strAppend "R" (showInt v)

main :: IO ()
main = do
  putStrLn (showEi (mapRi (Right 6)))
  putStrLn (showEi (mapRi (Left 9)))
  putStrLn (showEs (mapRs (Left "err")))
  putStrLn (showEs (mapRs (Right 4)))
