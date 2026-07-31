-- Must-use dropped without being consumed → REJECTED (AX0002).
-- 'Token' has no Drop, so Auto-Drop does NOT apply (unlike a droppable type) —
-- just like GHC, which treats every linear value as must-use.
dropIt :: Token %1 -> Int
dropIt x = 0
