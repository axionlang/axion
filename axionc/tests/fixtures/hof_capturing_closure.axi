-- Closure-argument linearity — CAPTURING-LAMBDA closure. A lambda that captures an enclosing
-- local (`\x -> x > n`, `n` a param of `keepAbove`) passed to `filter` over a HEAP element type
-- (`List Integer`). A preliminary inference recovers the lambda's in-context type; higher-order
-- specialization lifts it to a fresh CONCRETELY-SIGNED top-level function whose LEADING param is
-- the capture (`hoflamcap0 :: Integer -> Integer -> Bool; hoflamcap0 n x = x > n`, call
-- `filter (hoflamcap0 n) xs`) — the partial-application shape. So `filter$$hoflamcap0` gets the
-- concrete element type, consume-inference marks it `%1`, and the element-aliasing double-free
-- (AX0912) cannot arise. Before this a CAPTURING lambda over a heap type was AX0912-rejected
-- natively (its captures had no name/type for the type-directed lift). keepAbove 2 over {1,5,9}
-- keeps {5,9} = 2 on every backend, ASan + LSan clean.
keepAbove :: Integer -> List Integer -> Int
keepAbove n xs = length (filter (\x -> x > n) xs)

main :: Int
main = keepAbove (fromInt 2) (Cons (fromInt 1) (Cons (fromInt 5) (Cons (fromInt 9) Nil)))
