-- Whole-heap-param embed → `%1` (consume-inference Rule A′). `wrap` places its heap `Box`
-- parameter DIRECTLY into a returned tuple, so it must OWN it: the caller MOVES the Box in
-- (single owner), and the tuple's reclamation frees it exactly once. Without `%1` the borrowed
-- Box would be shared between the caller and the result → a deep-drop of both double-frees it.
-- 2 allocs (Box, tuple) == 2 frees.

data Box = Box { v :: Int }

wrap :: Box -> (Box, Int)
wrap b = (b, 5)

useT :: (Box, Int) %1 -> Int
useT t = case t of
  (bb, k) -> v bb + k

main :: Int
main = useT (wrap (Box { v = 7 }))
