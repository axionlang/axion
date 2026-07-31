-- Must FAIL with AX0002 (structural Drop propagation): 'Sess' looks droppable at
-- first sight, but it contains an 'Ep %1' field (must-use) → 'Sess' is must-use,
-- so it cannot be auto-dropped.
data Sess = Sess { ep :: Ep %1, count :: Int }

useSession :: Sess %1 -> Int
useSession s = 0
