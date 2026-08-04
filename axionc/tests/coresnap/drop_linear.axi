  |
4 | dropIt x = 0
  --> axionc/tests/fixtures/drop_linear.axi:4:8
error[AX0002]: must-use resource 'x' dropped without being consumed
  = help: endpoints, Token and handles are must-use (they have no Drop); consume it or return it (§2).
  |        ^ 'x' : Token %1 (no Drop)
