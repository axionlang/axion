-- Must FAIL with AX0001: the %1 U8 Buffer is consumed twice (contraction) —
-- 'xorInPlace' consumes ownership; you cannot consume the same buffer twice.
dup :: Buffer U8 %1 -> (Buffer U8, Buffer U8)
dup buf = (xorInPlace buf 1, xorInPlace buf 2)
