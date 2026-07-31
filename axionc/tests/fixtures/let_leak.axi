-- Must FAIL with AX0002: 's2' (a 'let' value of the must-use type Sess) is
-- dropped without being consumed. The linear discipline applies to 'let' values,
-- not only to parameters.
data Sess = Sess { ep :: Ep %1 }

mk :: Sess %1 -> Sess %1
mk s = s

leak :: Sess %1 -> Int
leak s = let s2 = mk s in 0
