   --> axionc/tests/fixtures/refine_malformed.axi:10:35
   --> axionc/tests/fixtures/refine_malformed.axi:17:18
   |
   |
   |                                   ^^^^^ here
   |                  ^^^ used here without its refined arguments
  --> axionc/tests/fixtures/refine_malformed.axi:4:11
  --> axionc/tests/fixtures/refine_malformed.axi:7:30
  = help: a refinement compares Int expressions (`+ - *`, literals, `len a` of an array parameter) with `< <= > >= == /=`, joined by `&&`/`||`
  = help: a refinement compares Int expressions (`+ - *`, literals, `len a` of an array parameter) with `< <= > >= == /=`, joined by `&&`/`||`
  = help: a refinement compares Int expressions (`+ - *`, literals, `len a` of an array parameter) with `< <= > >= == /=`, joined by `&&`/`||`
  = help: a refinement is checked at each call, against the arguments given there; pass the function to another one through a lambda that calls it in full
  |
  |
  |                              ^ here
  |           ^^^^^^^^^^^^^^^^^^^ here
10 | lenOfInt :: n:Int -> {i:Int | i < len n} -> Int
17 | asValue xs = map idx xs
4 | notInt :: {s:String | 0 <= s} -> Int
7 | unknownName :: {x:Int | 0 <= y} -> Int
error[AX0601]: ill-formed refinement: `n` is not an array parameter
error[AX0601]: ill-formed refinement: `y` is not a parameter named in this signature
error[AX0601]: ill-formed refinement: only `Int` values can be refined
error[AX0602]: `idx` has refined parameters and must be called with all of them
