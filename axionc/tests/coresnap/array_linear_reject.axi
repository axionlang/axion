   --> axionc/tests/fixtures/array_linear_reject.axi:18:12
   --> axionc/tests/fixtures/array_linear_reject.axi:26:13
   |
   |
   |
   |
   |
   |
   |                    ^^^ given to `setArray` here
   |                ^^^ given to `bump` here
   |                ^^^ given to `bump` here
   |             ^^^^^^^^^^^^^ 'cap' is moved into an owned position more than once
   |            ^^^ 'cap' used here…
   |       ^^^^^^^^^^^^^^^^^^^^^ …but ownership had already been moved here
  --> axionc/tests/fixtures/array_linear_reject.axi:8:13
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
  = help: after moving a %1 (consuming), you cannot read or consume it again — ownership has left this scope (§2).
  = rule: R5 (docs/spec.md#r5)
  = rule: R5 (docs/spec.md#r5)
  = rule: R6 (docs/spec.md#r6)
  |
  |
  |                    ^^^ given to `setArray` here
  |             ^^^^^^^^^^^^^ 'cap' is moved into an owned position more than once
10 |   let b = setArray cap 0 2 in
17 |   let a = setArray cap 0 1 in
18 |   getArray cap 0 + getArray a 0
26 |   let cap = newArray 10 0 in
27 |   let x = bump cap 1 in
28 |   let y = bump cap 2 in
8 |   let cap = newArray 10 0 in
9 |   let a = setArray cap 0 1 in
error[AX0001]: heap value 'cap' consumed 2 times (contraction forbidden)
error[AX0001]: heap value 'cap' consumed 2 times (contraction forbidden)
error[AX0004]: use of 'cap' after ownership was moved
