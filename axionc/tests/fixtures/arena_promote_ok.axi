-- Must PASS: 'node' lives in the sub-arena, but is moved to the parent arena
-- with 'promote parent node' before the reset — so 'node2' survives (Listing 3.4).
ok :: Arena -> Cell
ok parent =
  withSubArena parent (\sub ->
    let node = allocateCell sub in
    let node2 = promote parent node in
    node2)
