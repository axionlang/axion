   |
10 | mk xs = Two xs xs
   --> axionc/tests/fixtures/heap_duplication.axi:10:4
error[AX0001]: heap value 'xs' consumed 2 times (contraction forbidden)
  = help: a borrowed heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
   |    ^^ 'xs' is moved into an owned position more than once
