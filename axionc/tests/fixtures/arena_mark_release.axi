-- Deve FALHAR com AX0005: 'tmp' é alocado depois da marca e usado (devolvido)
-- DEPOIS do 'arena_release' — a sua memória já foi recuperada (Listagem 3.6).
badMark :: Arena -> Cell
badMark arena =
  let mark = arena_mark arena in
  let tmp = allocateCell arena in
  let done = arena_release mark in
  tmp
