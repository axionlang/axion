-- Must FAIL with AX0002: 'Token' is must-use (no Drop) and is dropped without
-- being consumed. (A droppable type would be accepted via Auto-Drop — see drop_ok.axi.)
dropIt :: Token %1 -> Int
dropIt x = 0
