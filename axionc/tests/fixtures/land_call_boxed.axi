-- Landing fixture for the deleted `returns_owned_heap`/`heap_ret` heuristic
-- (Phase A′): the result of a direct call returning a boxed `data` value is the
-- caller's property — droppable, with its drop type read from the lowering
-- annotation on the `CallDirect` node (deep `drop … : Pair`), not reconstructed
-- from the callee's signature. 1 alloc (the Pair) == 1 free.
data Pair = Pair { x :: Int, y :: Int }

mkPair :: Int -> Int -> Pair
mkPair a b = Pair { x = a, y = b }

main :: Int
main =
  let p = mkPair 7 8
  in 15
