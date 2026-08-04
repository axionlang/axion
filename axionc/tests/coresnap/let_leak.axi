   |
10 | leak s = let s2 = mk s in 0
   --> axionc/tests/fixtures/let_leak.axi:10:14
error[AX0002]: must-use resource 's2' dropped without being consumed
  = help: endpoints, Token and handles are must-use (they have no Drop); consume it or return it (§2).
   |              ^^^^^^^^^^ 's2' : Sess %1 (no Drop)
