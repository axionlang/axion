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
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |
   |                                    ^ given to the constructor `T` here
   |                                   ^ given to the constructor `T` here
   |                                  ^ given to the constructor `T` here
   |                                 ^ given to the constructor `T` here
   |                                ^^ given to the constructor `Vc` here
   |                              ^ given to the constructor `T` here
   |                              ^ given to the constructor `Vc` here
   |                              ^^ 'z' is moved into an owned position more than once
   |                            ^ given to the constructor `T` here
   |                      ^^ given to the constructor `Vc` here
   |                      ^^^^^^ 'z' is moved into an owned position more than once
   |                     ^ given to the constructor `T` here
   |                     ^^^^^^ 'z' is moved into an owned position more than once
   |                    ^ given to the constructor `Vc` here
   |                    ^^ 'z' is moved into an owned position more than once
   |                   ^ given to the constructor `T` here
   |                  ^ given to the constructor `T` here
   |                ^ given to the constructor `T` here
   |             ^^ 'z' is moved into an owned position more than once
   |        ^^ 'ys' is moved into an owned position more than once
   |      ^ 'y' is moved into an owned position more than once
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = rule: R5 (docs/spec.md#r5)
  = rule: R5 (docs/spec.md#r5)
  = rule: R5 (docs/spec.md#r5)
  = rule: R5 (docs/spec.md#r5)
  = rule: R5 (docs/spec.md#r5)
  = rule: R5 (docs/spec.md#r5)
  = rule: R5 (docs/spec.md#r5)
16 | mkLet xs = let z = xs in T z z
16 | mkLet xs = let z = xs in T z z
16 | mkLet xs = let z = xs in T z z
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
22 |   Vc y ys -> T (Vc y ys) (Vc y ys)
26 | mkWhere xs = T z z where z = xs
26 | mkWhere xs = T z z where z = xs
26 | mkWhere xs = T z z where z = xs
31 |   | otherwise = T z z
31 |   | otherwise = T z z
32 |   where z = xs
36 | mkCall xs = let z = idv xs in T z z
36 | mkCall xs = let z = idv xs in T z z
36 | mkCall xs = let z = idv xs in T z z
41 | mkLocal xs = let z = loc xs in T z z
41 | mkLocal xs = let z = loc xs in T z z
41 | mkLocal xs = let z = loc xs in T z z
error[AX0001]: heap value 'y' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'ys' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'z' consumed 2 times (contraction forbidden)
