-- Closure-argument linearity — UNSIGNED closure. A predicate passed to `filter` over a
-- HEAP element type (`List Integer`) that lacks a user signature. Higher-order
-- specialization recovers its CONCRETE type via inference (`infer_unsigned_sigs`), signs
-- it, and specializes `filter$$isBig` — a direct-call clone whose concrete element type
-- lets consume-inference mark it `%1`, so the shared-element double-free (the AX0912 class)
-- cannot arise. Without the recovered signature this was AX0912-rejected natively (the
-- closure had no type for the type-directed specialization). Runs = 2 on every backend,
-- ASan + LSan clean.
isBig x = x > fromInt 2

main :: Int
main = length (filter isBig (Cons (fromInt 1) (Cons (fromInt 5) (Cons (fromInt 9) Nil))))
