-- Deep-drop (§2): sum type with a heap payload. `Some P` owns a `P`; the
-- destructor `axion_drop_Opt` dispatches on the tag and frees the `P` in the `Some`
-- arm. main = val (Some (P 10 5)) + val None = 15 + 0 = 15.
data P = P { a :: Int, b :: Int }
data Opt = None | Some P

val :: Opt -> Int
val o = case o of
  None -> 0
  Some q -> a q + b q

main :: Int
main = val (Some (P { a = 10, b = 5 })) + val None
