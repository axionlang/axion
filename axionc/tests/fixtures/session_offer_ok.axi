-- Escolha externa bem-formada: o `Offer` inclui o ramo `Closed` (T5). Aceite.
handler :: Ep (Offer (Live End) (Closed End)) %1 -> IO ()
handler c = offer c
