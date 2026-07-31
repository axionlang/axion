-- Must FAIL with AX0001: the linear record 'r' (%1) is CONSUMED twice.
-- (Reading it twice, e.g. tag r + tag r, would be allowed — those are borrows.)
data Res = Res { tag :: Int }

dupRes :: Res %1 -> (Res, Res)
dupRes r = (r, r)
