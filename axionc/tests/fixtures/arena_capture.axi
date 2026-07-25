-- Deve FALHAR com AX0003: a closure '\x -> node' captura 'node' (que vive na
-- sub-arena) e é devolvida — o escape pode ser por retorno OU por captura em
-- closure (§3C).
grab :: Arena -> (Cell -> Cell)
grab parent =
  withSubArena parent (\sub ->
    let node = allocateCell sub in
    \x -> node)
