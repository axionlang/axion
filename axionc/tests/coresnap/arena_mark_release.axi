  |
  |
  |
6 |   let tmp = allocateCell arena in
7 |   let done = arena_release mark in
8 |   tmp
  --> axionc/tests/fixtures/arena_mark_release.axi:8:3
  |              ^^^^^^^^^^^^^^^^^^ …but arena_release reclaimed the memory here
error[AX0005]: 'tmp' used after 'arena_release' (memory already reclaimed)
  = help: everything allocated after a mark is reclaimed on arena_release; consume it before, or promote it past the mark (§3).
  |   ^^^ 'tmp' used here…
  |             ^^^^^^^^^^^^^^^^^^ 'tmp' was allocated after the mark here
