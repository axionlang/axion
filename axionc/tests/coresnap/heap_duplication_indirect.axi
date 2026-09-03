   --> axionc/tests/fixtures/heap_duplication_indirect.axi:16:20
   --> axionc/tests/fixtures/heap_duplication_indirect.axi:22:6
   --> axionc/tests/fixtures/heap_duplication_indirect.axi:22:8
   --> axionc/tests/fixtures/heap_duplication_indirect.axi:26:30
   --> axionc/tests/fixtures/heap_duplication_indirect.axi:32:13
   --> axionc/tests/fixtures/heap_duplication_indirect.axi:36:21
   --> axionc/tests/fixtures/heap_duplication_indirect.axi:41:22
   |
   |
   |
   |
   |
   |
   |
   |                              ^^ 'z' is moved into an owned position more than once
   |                      ^^^^^^ 'z' is moved into an owned position more than once
   |                     ^^^^^^ 'z' is moved into an owned position more than once
   |                    ^^ 'z' is moved into an owned position more than once
   |             ^^ 'z' is moved into an owned position more than once
   |        ^^ 'ys' is moved into an owned position more than once
   |      ^ 'y' is moved into an owned position more than once
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ freely, but moving it by ownership (into a constructor/tuple/%1 argument) may happen only once — to share it by ownership, 'split' it into two %0.5 halves (§2).
16 | mkLet xs = let z = xs in T z z
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
26 | mkWhere xs = T z z where z = xs
32 |   where z = xs
36 | mkCall xs = let z = idv xs in T z z
41 | mkLocal xs = let z = loc xs in T z z
error[AX0001]: heap value 'y' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'ys' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
