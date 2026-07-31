-- Well-formed external choice: the `Offer` includes the `Closed` branch (T5). Accepted.
handler :: Ep (Offer (Live End) (Closed End)) %1 -> IO ()
handler c = offer c
