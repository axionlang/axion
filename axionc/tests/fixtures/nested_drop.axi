-- Deep-drop (§2): registo aninhado. `Box` possui um `P` (alocação separada). O
-- destrutor gerado `axion_drop_Box` liberta o `P` interno e depois o `Box` — um
-- free plano perderia o interno. main = a(inner)+b(inner)+tag = 3+4+5 = 12.
data P = P { a :: Int, b :: Int }
data Box = Box { inner :: P, tag :: Int }

boxSum :: Box -> Int
boxSum x = a (inner x) + b (inner x) + tag x

main :: Int
main = boxSum (Box { inner = P { a = 3, b = 4 }, tag = 5 })
