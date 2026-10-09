-- Array Float (§A): dense f64 carried through the uniform i64 array ABI as the f64 bit pattern,
-- enabled by the element-polymorphic newArray/getArray/setArray signatures. `fillF` owns the array
-- (setArray consumes + returns, in place); `dotF` BORROWS it (read-only getArray loop) — the fixpoint
-- borrow analysis reclaims the array exactly once. Float arithmetic (+. *.) in a hot loop.
--   a = [1.0, 2.0, 3.0, 4.0];  dot(a, a) = 1 + 4 + 9 + 16 = 30.0
fillF :: Array Float -> Int -> Array Float
fillF a i = if i == 4 then a else let a2 = setArray a i (toFloat (i + 1)) in fillF a2 (i + 1)

dotF :: Array Float -> Int -> Float -> Float
dotF a i acc = if i == 4 then acc else dotF a (i + 1) (acc +. (getArray a i *. getArray a i))

main :: IO ()
main = let a = fillF (newArray 4 0.0) 0 in putStrLn (showFloat (dotF a 0 0.0))
