  --> axionc/tests/fixtures/use_after_consume.axi:5:10
  = help: reading (borrowing) a %1 is free and unlimited; moving ownership (consuming) may happen only once — to share it by ownership, use 'split' into two %0.5 halves (§2).
  |
  |          ^ 'x' is %1: consumable only once
5 | useTwice x = (x, x)
error[AX0001]: linear resource 'x' consumed 2 times (contraction forbidden)
