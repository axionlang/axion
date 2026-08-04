  |
  |
7 | bad x = sink x + x
7 | bad x = sink x + x
  --> axionc/tests/fixtures/use_after_move.axi:7:18
  |              ^ …but ownership had already been moved here
error[AX0004]: use of 'x' after ownership was moved
  = help: after moving a %1 (consuming), you cannot read or consume it again — ownership has left this scope (§2).
  |                  ^ 'x' used here…
