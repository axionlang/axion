-- `uncons` over a TUPLE element returns `Maybe ((K,V), List (K,V))`; `pick` BORROWS that result,
-- peels the interior tuple head `h`, and CONSUMES it via `sndof` (which frees the tuple) while the
-- owner still deep-drops the `Maybe` → double-free. The real cause is the general consume-of-a-
-- borrowed-interior-tuple-field class (NOT a monomorphizer/lowering bug — `uncons$(K,V)` itself
-- lowers fine; a safe read of the tail is clean, see `uncons_safe_tuple_read.axi`). The drop-
-- balance verifier now catches it DIRECTLY (AX0910, `bind_pattern`'s `CPat::Tuple` arm), so the
-- former `peel_result_over_tuple` AX0912 guard is RETIRED. Native rejects (AX0910); the interpreter
-- reclaims via Rust Drop and runs it → 5.
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
