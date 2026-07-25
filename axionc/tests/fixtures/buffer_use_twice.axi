-- Deve FALHAR com AX0001: o Buffer %1 é consumido duas vezes (contração) —
-- 'xorInPlace' consome a posse; não se pode consumir o mesmo buffer duas vezes.
dup :: Buffer %1 -> (Buffer, Buffer)
dup buf = (xorInPlace buf 1, xorInPlace buf 2)
