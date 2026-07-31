-- AX0300: the protocol is `Send Int End`, but the body does `recv` — the operation
-- does not follow the endpoint's session type.
worker :: Ep (Send Int End) %1 -> IO ()
worker chan = do
  (x, c2) <- recv chan
  close c2
