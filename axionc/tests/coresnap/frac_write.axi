   |
11 |   (a, b) -> writeCfg a
   |                      ^ 'a' is %0.5 (shared read): passed to a %1 parameter (write)
   --> axionc/tests/fixtures/frac_write.axi:11:22
error[AX0006]: write through the %0.5 half 'a'
  = help: a %0.5 half grants read only; to recover write access, recombine the two halves with 'join a b' (which returns the %1) (§2).
