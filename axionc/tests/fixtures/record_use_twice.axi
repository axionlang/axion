-- Deve FALHAR com AX0001: o registo linear 'r' (%1) é CONSUMIDO duas vezes.
-- (Lê-lo duas vezes, ex.: tag r + tag r, seria permitido — são empréstimos.)
data Res = Res { tag :: Int }

dupRes :: Res %1 -> (Res, Res)
dupRes r = (r, r)
