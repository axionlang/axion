   --> axionc/tests/fixtures/heap_alias_rejected.axi:14:11
   |
   |
   |
   |             ^ given to the constructor `W` here
   |             ^ given to the constructor `W` here
   |           ^^^^^^^^^^^^^^^^^^^^^^^^^^ 'x' is moved into an owned position more than once
  = help: a heap value may be READ any number of times, but given away (to a constructor, a tuple, or a function that takes ownership of the argument) only once. A function takes ownership when its parameter is `%1`, or when it keeps or passes on part of the argument — the compiler infers that, e.g. a function passing a field to `filter` owns the value, because `filter` consumes the list it is given. To use the value twice, make those calls only read it, compute both results in one call, or 'split' it into two %0.5 halves (§2).
14 |   let x = Cons 1 (Cons 2 (Cons 3 Nil))
15 |       a = W x
16 |       b = W x
error[AX0001]: heap value 'x' consumed 2 times (contraction forbidden)
