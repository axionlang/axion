-- pipe3.axi — WORKER↔WORKER CHAIN (the N=3 generalization of `connect`): a PRODUCER, a RELAY, and a
-- CONSUMER wired into a pipeline by two channels. Data flows worker→worker→worker (never routed
-- through `main`): `prod` sends 20 to `relay`, which doubles it and sends 40 to `cons`, which
-- returns it. The RELAY holds TWO endpoints — recv-from-upstream and send-to-downstream. Deadlock-
-- free BY CONSTRUCTION: a linear 3-node chain is rank-ordered (prod < relay < cons), so
-- `AxionSession`'s `no_deadlock` covers it. GC-free + race-free (linear endpoints). Runs identically
-- on interp, --dev, and --release.
prod :: Ep (Send Int End) %1 -> IO ()
prod a = do
  a2 <- send a 20
  close a2

relay :: Ep (Recv Int End) %1 -> Ep (Send Int End) %1 -> IO ()
relay up down = do
  (x, up2) <- recv up
  close up2
  down2 <- send down (x * 2)
  close down2

cons :: Ep (Recv Int End) %1 -> Int
cons b = do
  (y, b2) <- recv b
  close b2
  y

main :: Int
main = pipe3 prod relay cons
