-- Deve FALHAR com AX0002: 's2' (um valor 'let' de tipo must-use Sess) é largado
-- sem ser consumido. A disciplina linear aplica-se a valores 'let', não só a
-- parâmetros.
data Sess = Sess { ep :: Ep %1 }

mk :: Sess %1 -> Sess %1
mk s = s

leak :: Sess %1 -> Int
leak s = let s2 = mk s in 0
