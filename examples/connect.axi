-- connect.axi — WORKER↔WORKER communication (the concurrency-topology milestone beyond the star):
-- a PRODUCER sends a value DIRECTLY to a CONSUMER over one channel — peer-to-peer, not routed
-- through `main`. `connect prod cons` runs both on the two ends of a fresh channel and returns the
-- consumer's result. Deadlock-free BY CONSTRUCTION: a 2-node chain is trivially rank-ordered
-- (producer < consumer), so `AxionSession`'s `no_deadlock` covers it. GC-free + race-free (linear
-- endpoints) like all Axión concurrency. Runs identically on interp, --dev, and --release.
prod :: Ep (Send Int End) %1 -> IO ()
prod a = do
  a2 <- send a 42
  close a2

cons :: Ep (Recv Int End) %1 -> Int
cons b = do
  (x, b2) <- recv b
  close b2
  x

main :: Int
main = connect prod cons
