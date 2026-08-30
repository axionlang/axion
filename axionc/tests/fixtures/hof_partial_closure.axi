-- Closure-argument linearity — PARTIAL-APPLICATION closure. A named predicate applied to
-- some of its args (`gt (fromInt 2)`) passed to `filter` over a HEAP element type. The
-- closure carries a pre-bound value; higher-order specialization threads that captured arg
-- as a LEADING parameter of the clone (`filter$$gt cap xs`, call `filter$$gt (fromInt 2)
-- xs`) — a direct-call clone whose concrete element type lets consume-inference mark it `%1`,
-- so the element-aliasing double-free (AX0912) cannot arise. Before this a partial-application
-- closure (like a lambda) was AX0912-rejected natively — its head was `App`, not a bare name.
-- keepAbove2 over {1,5,9} keeps {5,9} = 2 on every backend, ASan + LSan clean.
gt :: Integer -> Integer -> Bool
gt n x = x > n

main :: Int
main = length (filter (gt (fromInt 2)) (Cons (fromInt 1) (Cons (fromInt 5) (Cons (fromInt 9) Nil))))
