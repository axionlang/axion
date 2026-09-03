  --> axionc/tests/fixtures/buffer_use_twice.axi:4:5
  = help: reading (borrowing) a %1 is free and unlimited; moving ownership (consuming) may happen only once — to share it by ownership, use 'split' into two %0.5 halves (§2).
  |
  |     ^^^ 'buf' is %1: consumable only once
4 | dup buf = (xorInPlace buf 1, xorInPlace buf 2)
error[AX0001]: linear resource 'buf' consumed 2 times (contraction forbidden)
