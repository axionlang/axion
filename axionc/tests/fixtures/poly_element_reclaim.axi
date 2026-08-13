-- A generic container of HEAP elements (`Lst Box`) must reclaim its ELEMENTS when
-- dropped, not just the spine. The generic destructor `axion_drop_Lst` frees the
-- cons cells but the polymorphic element field is never a drop slot, so the `Box`
-- payloads leaked. A `case` on a concrete `Lst Box` value now resolves the element
-- and recursive-spine field drops to the monomorphic destructor `axion_drop_Lst$Box`
-- (from the scrutinee's concrete key), reclaiming the elements — while a `Lst Int`
-- (Int elements) still does NOT deep-drop its scalars (no corruption). allocs==frees.
data Box = Box Int
data Lst a = LNil | LCons a (Lst a)

val :: Box -> Int
val b = case b of Box n -> n

-- returns the head element; the tail (with its Box elements) is dead and must be
-- deep-dropped via the monomorphic destructor.
headOr :: Box -> Lst Box -> Box
headOr dflt xs = case xs of
  LNil -> dflt
  LCons y ys -> y

main :: IO ()
main = putStrLn (show (val (headOr (Box 9) (LCons (Box 1) (LCons (Box 2) LNil)))))
