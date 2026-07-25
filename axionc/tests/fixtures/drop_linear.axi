-- Deve FALHAR com AX0002: 'Token' é must-use (sem Drop) e é largado sem consumo.
-- (Um tipo droppable seria aceite via Auto-Drop — ver drop_ok.axi.)
dropIt :: Token %1 -> Int
dropIt x = 0
