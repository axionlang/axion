-- Well-typed session (§6): the endpoint sends an Int and closes, following the
-- protocol `Send Int End`. `check_sessions` accepts; the endpoint's linearity (%1)
-- and protocol fidelity are both satisfied.
worker :: Ep (Send Int End) %1 -> IO ()
worker chan = do
  c2 <- send chan 42
  close c2
