  |
7 | useSession s = 0
  --> axionc/tests/fixtures/struct_mustuse.axi:7:12
error[AX0002]: must-use resource 's' dropped without being consumed
  = help: endpoints, Token and handles are must-use (they have no Drop); consume it or return it (§2).
  |            ^ 's' : Sess %1 (no Drop)
