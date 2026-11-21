-- WAS UNSAFE, now copied (verifier-caught AX0910 `DropOfAlias` without the copy): consuming a BORROWED INTERIOR
-- TUPLE field. `fstof` CONSUMES its tuple (it stores the heap half `a` in a new `Just`, so the result keeps part
-- of the tuple and the function owns it; a function that only RETURNS `a` borrows instead). `pick` BORROWS `m`, extracts the interior tuple `h` (through
-- the nested `Just p` / `(h, rest)` cases), and passes `h` to the consuming `fstof` — so `h` is freed
-- by `fstof` AND by the caller's deep-drop of the `Maybe` → double-free. (A reader returning the
-- SCALAR half borrows its tuple instead and is safe: `tuple_scalar_reader.axi`.) This was a PRE-EXISTING,
-- unguarded, verifier-blind hole (plain user code, no `uncons`, no AX0912 trigger) until the verifier
-- learned to track borrowed TUPLE-scrutinee fields as interior aliases (the `CPat::Tuple` arm in
-- `bind_pattern`). Auto-Drop now COPIES `h` before the consuming call, so native runs it too (= 1);
-- with `AXION_NO_ALIAS_COPY` the verifier still rejects the uncopied shape. Contrast the
-- OWNED-tuple fixtures (tuple_owned / nested_tuple_extract_escape / tuple_elem_discard), which stay
-- clean because they destructure tuples they OWN.
mk :: Int -> (String, Int)
mk n = ("k", n)
fstof :: (String, Int) -> Maybe String
fstof t = case t of
  (a, b) -> Just a
mlen :: Maybe String -> Int
mlen m = case m of
  Just s -> strLen s
  Nothing -> 0
pick :: Maybe ((String, Int), List (String, Int)) -> Int
pick m = case m of
  Just p -> case p of
    (h, rest) -> mlen (fstof h)
  Nothing -> 0
build :: Int -> Maybe ((String, Int), List (String, Int))
build n = Just (mk n, Cons (mk (n + 1)) Nil)
main :: IO ()
main = putStr (show (pick (build 5)))
