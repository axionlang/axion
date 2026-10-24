-- The nested-tuple poly-payload residual (CLOSED). An element-EXTRACTING `%1` list consumer
-- (`take`/`drop`/`head`/`last`) over a TUPLE element type (`List (Integer, Integer)`) once
-- silently dropped `main` natively (the monomorphizer never materialized the clone over a tuple
-- element — `discharge_owning` bailed on a `Ty::Tuple`). It now monomorphizes (`take$(Integer,
-- Integer)`, key `tuple2$Integer$Integer`) and reclaims the payloads, so this COMPILES + RUNS
-- (= 3) identically on interp / cranelift / llvm, leak- and corruption-free. Only the `uncons`
-- PEEL over a tuple element (nested tuple-in-tuple) stays AX0912-gated — see
-- `uncons_peel_tuple_reject.axi`.
pairUp :: Integer -> (Integer, Integer)
pairUp n = (n, fromInt 0)
fstT :: (Integer, Integer) -> Integer
fstT t = case t of
  (a, b) -> a
addI :: Integer -> Integer -> Integer
addI a b = a + b
main :: IO ()
main = putStrLn (showInteger (foldl addI 0 (map fstT (take 2 (map pairUp (map fromInt (range 1 4)))))))
