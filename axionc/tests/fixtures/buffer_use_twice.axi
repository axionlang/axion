-- Deve FALHAR com AX0001: o Buffer U8 %1 é consumido duas vezes (contração) —
-- 'xorInPlace' consome a posse; não se pode consumir o mesmo buffer duas vezes.
dup :: Buffer U8 %1 -> (Buffer U8, Buffer U8)
dup buf = (xorInPlace buf 1, xorInPlace buf 2)
