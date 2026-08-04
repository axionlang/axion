  |
6 | dupRes r = (r, r)
  --> axionc/tests/fixtures/record_use_twice.axi:6:8
error[AX0001]: linear resource 'r' consumed 2 times (contraction forbidden)
  = help: reading (borrowing) a %1 is free and unlimited; moving ownership (consuming) may happen only once — to share it by ownership, use 'split' into two %0.5 halves (§2).
  |        ^ 'r' is %1: consumable only once
