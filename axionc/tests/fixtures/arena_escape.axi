-- Deve FALHAR com AX0003: 'node' vive na sub-arena 'sub' e é devolvido do
-- 'withSubArena' — sobreviveria ao reset da sub-arena (Listagem 3.5, §3).
escapes :: Arena -> Cell
escapes parent = withSubArena parent (\sub -> let node = allocateCell sub in node)
