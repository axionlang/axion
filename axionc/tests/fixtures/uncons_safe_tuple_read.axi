-- `uncons` over a TUPLE element (`List (String, Int)`) returning `Maybe ((String,Int), List
-- (String,Int))`, where the consumer only READS the tail `rest` (`length rest`) and merely
-- DISCARDS the borrowed head `h` — no consume of a borrowed interior, so it is SOUND. The retired
-- `peel_result_over_tuple` AX0912 guard used to OVER-reject this on the result type alone; the
-- drop-balance verifier correctly accepts it, so it now COMPILES + RUNS (= 1) identically on
-- interp / cranelift / llvm, leak- and corruption-free. Contrast `uncons_peel_tuple_reject.axi`,
-- which CONSUMES the peeled head and is AX0910-rejected.
mkp :: Int -> (String, Int)
mkp n = ("k", n)
pick :: Maybe ((String, Int), List (String, Int)) -> Int
pick m = case m of
  Just p -> case p of
    (h, rest) -> length rest
  Nothing -> 0
main :: IO ()
main = putStr (show (pick (uncons (Cons (mkp 5) (Cons (mkp 6) Nil)))))
