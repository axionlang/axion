-- Deve FALHAR com AX0001: o registo linear 'r' (%1) é lido duas vezes.
data Res = Res { tag :: Int }

dupRes :: Res %1 -> Int
dupRes r = tag r + tag r
