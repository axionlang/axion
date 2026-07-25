-- Deve PASSAR: 'node' vive na sub-arena, mas é movido para a arena-pai com
-- 'promote parent node' antes do reset — logo 'node2' sobrevive (Listagem 3.4).
ok :: Arena -> Cell
ok parent =
  withSubArena parent (\sub ->
    let node = allocateCell sub in
    let node2 = promote parent node in
    node2)
