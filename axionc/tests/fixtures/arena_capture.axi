-- Must FAIL with AX0003: the closure '\x -> node' captures 'node' (which lives
-- in the sub-arena) and is returned — the escape can be by return OR by capture
-- in a closure (§3C).
grab :: Arena -> (Cell -> Cell)
grab parent =
  withSubArena parent (\sub ->
    let node = allocateCell sub in
    \x -> node)
