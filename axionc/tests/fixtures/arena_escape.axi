-- Must FAIL with AX0003: 'node' lives in the sub-arena 'sub' and is returned
-- from 'withSubArena' — it would outlive the sub-arena's reset (Listing 3.5, §3).
escapes :: Arena -> Cell
escapes parent = withSubArena parent (\sub -> let node = allocateCell sub in node)
