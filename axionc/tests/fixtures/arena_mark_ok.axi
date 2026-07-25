-- Deve PASSAR: 'tmp' (alocado depois da marca) é usado ANTES do 'arena_release';
-- o que é devolvido ('n') não vive na região reclamada (Listagem 3.6).
useCell :: Cell -> Int
useCell c = 0

okMark :: Arena -> Int
okMark arena =
  let mark = arena_mark arena in
  let tmp = allocateCell arena in
  let n = useCell tmp in
  let done = arena_release mark in
  n
