-- Deve FALHAR com AX0002 (propagação estrutural de Drop): 'Sess' é droppable à
-- primeira vista, mas contém um campo 'Ep %1' (must-use) → 'Sess' é must-use,
-- logo não pode ser auto-dropped.
data Sess = Sess { ep :: Ep %1, count :: Int }

useSession :: Sess %1 -> Int
useSession s = 0
