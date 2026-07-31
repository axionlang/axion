-- Must FAIL with AX0005: 'tmp' is allocated after the mark and used (returned)
-- AFTER 'arena_release' — its memory has already been reclaimed (Listing 3.6).
badMark :: Arena -> Cell
badMark arena =
  let mark = arena_mark arena in
  let tmp = allocateCell arena in
  let done = arena_release mark in
  tmp
