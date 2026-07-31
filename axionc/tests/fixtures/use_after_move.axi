-- Must FAIL with AX0004: 'x' is consumed by 'sink x' (ownership leaves) and then
-- read again in '+ x'. Reading BEFORE consuming (x + sink x) would be OK.
sink :: Int %1 -> Int
sink x = x

bad :: Int %1 -> Int
bad x = sink x + x
