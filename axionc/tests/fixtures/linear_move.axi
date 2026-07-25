-- Reclamação entre funções (Auto-Drop §2, linear). 'make' aloca um Box e
-- devolve-o (o chamador passa a possuí-lo); 'take' recebe-o por %1 (posse
-- movida) e liberta-o no seu ponto de morte. main = take (make 42) → 42, com
-- 1 alloc == 1 free (o objecto atravessa a fronteira e é libertado uma vez).
data Box = Box { val :: Int }

make :: Int -> Box
make n = Box { val = n }

take :: Box %1 -> Int
take b = val b

main :: Int
main = take (make 42)
