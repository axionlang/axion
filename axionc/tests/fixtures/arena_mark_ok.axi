-- Must PASS: 'tmp' (allocated after the mark) is used BEFORE 'arena_release';
-- what is returned ('n') does not live in the reclaimed region (Listing 3.6).
useCell :: Cell -> Int
useCell c = 0

okMark :: Arena -> Int
okMark arena =
  let mark = arena_mark arena in
  let tmp = allocateCell arena in
  let n = useCell tmp in
  let done = arena_release mark in
  n
