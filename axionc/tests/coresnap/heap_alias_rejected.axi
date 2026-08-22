   |
14 |   let x = Cons 1 (Cons 2 (Cons 3 Nil))
   --> axionc/tests/fixtures/heap_alias_rejected.axi:14:11
error[AX0001]: heap value 'x' consumed 2 times (contraction forbidden)
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
   |           ^^^^^^^^^^^^^^^^^^^^^^^^^^ 'x' is moved into an owned position more than once
