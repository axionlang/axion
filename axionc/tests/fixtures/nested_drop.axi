-- Deep-drop (§2): nested record. `Box` owns a `P` (a separate allocation). The
-- generated destructor `axion_drop_Box` frees the inner `P` and then the `Box` — a
-- flat free would leak the inner one. main = a(inner)+b(inner)+tag = 3+4+5 = 12.
data P = P { a :: Int, b :: Int }
data Box = Box { inner :: P, tag :: Int }

boxSum :: Box -> Int
boxSum x = a (inner x) + b (inner x) + tag x

main :: Int
main = boxSum (Box { inner = P { a = 3, b = 4 }, tag = 5 })
