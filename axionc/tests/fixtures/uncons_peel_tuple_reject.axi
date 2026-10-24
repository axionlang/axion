-- The residual nested-tuple-in-tuple monomorphization hole (the last AX0912 floor for tuple
-- elements). The `uncons` PEEL returns `Maybe ((K,V), List (K,V))` — a tuple whose FIRST
-- component is itself the extracted tuple element and whose second is the tail list. Over a
-- TUPLE element the specialized `uncons$(K,V)` clone builds that inner peel tuple UNTYPED (the
-- materialize_specs re-spanning gap), so a deep-drop of the result double-frees — and the
-- drop-verifier does NOT catch it. AX0912 keeps it fail-closed on both native backends; the
-- interpreter reclaims via Rust Drop and runs it → 5. Every OTHER tuple-element consumer
-- (`take`/`drop`/`head`/`last`/`reverse`/`map`/`length`) now lowers soundly — see
-- `tuple_element_extract_reclaim.axi`.
mkp :: Int -> (String, Int)
mkp n = ("k", n)
sndof :: (String, Int) -> Int
sndof t = case t of
  (a, b) -> b
pick :: Maybe ((String, Int), List (String, Int)) -> Int
pick m = case m of
  Just p -> case p of
    (h, rest) -> sndof h
  Nothing -> 0
main :: IO ()
main = putStr (show (pick (uncons (Cons (mkp 5) (Cons (mkp 6) Nil)))))
