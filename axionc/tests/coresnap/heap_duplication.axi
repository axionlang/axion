   |
10 | mk xs = Two xs xs
   --> axionc/tests/fixtures/heap_duplication.axi:10:4
error[AX0001]: linear resource 'xs' consumed 2 times (contraction forbidden)
  = help: reading (borrowing) a %1 is free and unlimited; moving ownership (consuming) may happen only once — to share it by ownership, use 'split' into two %0.5 halves (§2).
   |    ^^ 'xs' is %1: consumable only once
