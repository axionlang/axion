  --> axionc/tests/fixtures/arena_mark_release.axi:8:3
  = help: everything allocated after a mark is reclaimed on arena_release; consume it before, or promote it past the mark (§3).
  |
  |
  |
  |              ^^^^^^^^^^^^^^^^^^ …but arena_release reclaimed the memory here
  |             ^^^^^^^^^^^^^^^^^^ 'tmp' was allocated after the mark here
  |   ^^^ 'tmp' used here…
6 |   let tmp = allocateCell arena in
7 |   let done = arena_release mark in
8 |   tmp
error[AX0005]: 'tmp' used after 'arena_release' (memory already reclaimed)
