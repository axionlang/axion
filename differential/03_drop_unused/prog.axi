-- Must-use largado sem consumo → REJEITADO (AX0002).
-- 'Token' não tem Drop, por isso o Auto-Drop NÃO se aplica (ao contrário de um
-- tipo droppable) — tal como o GHC, que trata todo o linear como must-use.
dropIt :: Token %1 -> Int
dropIt x = 0
