-- Closure-argument linearity — LAMBDA-LITERAL closure. A non-capturing lambda predicate
-- passed to `filter` over a HEAP element type (`List Integer`). Higher-order specialization
-- LIFTS the lambda to a fresh top-level function, recovers its concrete type via inference
-- (only a MONOMORPHIC lambda is lifted — a polymorphic one like `\x -> x` stays inline so it
-- keeps generalizing), signs it, and specializes `filter$$hoflam<N>`. So the element-aliasing
-- double-free (AX0912) cannot arise. Before this a lambda closure over a heap type was
-- AX0912-rejected natively (no name/type for the type-directed specialization). Runs = 2 on
-- every backend, ASan + LSan clean. A CAPTURING lambda stays generic (the conservative floor).
main :: Int
main = length (filter (\x -> x > fromInt 2) (Cons (fromInt 1) (Cons (fromInt 5) (Cons (fromInt 9) Nil))))
