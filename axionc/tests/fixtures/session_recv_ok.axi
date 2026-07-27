-- Sessão bem-tipada: recebe um Int e fecha (`Recv Int End`).
worker :: Ep (Recv Int End) %1 -> IO ()
worker chan = do
  (x, c2) <- recv chan
  close c2
