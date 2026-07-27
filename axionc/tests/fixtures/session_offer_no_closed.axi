-- AX0303 (T5): a escolha externa (`Offer`/`&`) não inclui o ramo `Closed`, logo o
-- cancelamento de um par em pânico ficaria por tratar (§7).
handler :: Ep (Offer (Live End)) %1 -> IO ()
handler c = offer c
