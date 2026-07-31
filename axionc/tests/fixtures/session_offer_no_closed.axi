-- AX0303 (T5): the external choice (`Offer`/`&`) does not include the `Closed` branch,
-- so a panicking peer's cancellation would go unhandled (§7).
handler :: Ep (Offer (Live End)) %1 -> IO ()
handler c = offer c
