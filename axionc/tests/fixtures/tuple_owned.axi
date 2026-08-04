-- Tuple-owned %1: a `%1` tuple parameter whose elements include heap-typed
-- `data` types (`Box`). The generated tuple destructor deep-drops each
-- `data`-typed element and flat-frees the shell.
-- 3 allocs (Box a, Box b, tuple shell) == 3 frees.

data Box = Box { v :: Int }

useTuple :: (Box, Box) %1 -> Int
useTuple t = case t of (a, b) -> v a + v b

main :: Int
main = useTuple (Box { v = 1 }, Box { v = 3 })
