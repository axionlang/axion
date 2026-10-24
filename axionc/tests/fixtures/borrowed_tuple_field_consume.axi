-- GENUINELY UNSAFE, drop-verifier-caught (AX0910 `DropOfAlias`): consuming a BORROWED INTERIOR
-- TUPLE field. `sndof` CONSUMES its tuple (its Core is `drop t : tuple2$String$Int` — it reclaims
-- the discarded heap field `a`). `pick` BORROWS `m`, extracts the interior tuple `h` (through the
-- nested `Just p` / `(h, rest)` cases), and passes `h` to the consuming `sndof` — so `h` is freed by
-- `sndof` AND by the caller's deep-drop of the `Maybe` → double-free. This was a PRE-EXISTING,
-- unguarded, verifier-blind hole (plain user code, no `uncons`, no AX0912 trigger) until the verifier
-- learned to track borrowed TUPLE-scrutinee fields as interior aliases (the `CPat::Tuple` arm in
-- `bind_pattern`). The verifier now rejects it; the interpreter still runs it (= 5). Contrast the
-- OWNED-tuple fixtures (tuple_owned / nested_tuple_extract_escape / tuple_elem_discard), which stay
-- clean because they destructure tuples they OWN.
mk :: Int -> (String, Int)
mk n = ("k", n)
sndof :: (String, Int) -> Int
sndof t = case t of
  (a, b) -> b
pick :: Maybe ((String, Int), List (String, Int)) -> Int
pick m = case m of
  Just p -> case p of
    (h, rest) -> sndof h
  Nothing -> 0
build :: Int -> Maybe ((String, Int), List (String, Int))
build n = Just (mk n, Cons (mk (n + 1)) Nil)
main :: IO ()
main = putStr (show (pick (build 5)))
