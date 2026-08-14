-- An OWNED (`%1`) parameter that a function never uses must still be reclaimed
-- (Auto-Drop), not leaked. `consume xs = 0` takes ownership of `xs` and returns 0
-- — effectively "drop it". The use-driven drop insertion places a drop at a value's
-- LAST USE, and an unused param has none, so `xs` was left un-dropped → total leak
-- (native `AXION_HEAP_STATS` showed N allocs, 0 frees). A never-used owned param is
-- now dropped at the function entry. Concrete parametric element type → the
-- monomorphic destructor reclaims the elements too. allocs == frees.
data Box = Box Int
data Lst a = LNil | LCons a (Lst a)

consume :: Lst Box %1 -> Int
consume xs = 0

main :: IO ()
main = putStrLn (show (consume (LCons (Box 1) (LCons (Box 2) LNil))))
