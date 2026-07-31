-- Well-typed session: receives an Int and closes (`Recv Int End`).
worker :: Ep (Recv Int End) %1 -> IO ()
worker chan = do
  (x, c2) <- recv chan
  close c2
