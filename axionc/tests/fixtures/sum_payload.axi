-- Deep-drop (§2): tipo-soma com payload de heap. `Some P` possui um `P`; o
-- destrutor `axion_drop_Opt` despacha pelo tag e liberta o `P` no braço `Some`.
-- main = val (Some (P 10 5)) + val None = 15 + 0 = 15.
data P = P { a :: Int, b :: Int }
data Opt = None | Some P

val :: Opt -> Int
val o = case o of
  None -> 0
  Some q -> a q + b q

main :: Int
main = val (Some (P { a = 10, b = 5 })) + val None
