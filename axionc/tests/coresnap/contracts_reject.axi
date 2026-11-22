   --> axionc/tests/fixtures/contracts_reject.axi:11:30
   --> axionc/tests/fixtures/contracts_reject.axi:15:14
   --> axionc/tests/fixtures/contracts_reject.axi:19:22
   --> axionc/tests/fixtures/contracts_reject.axi:24:14
   |
   |
   |
   |
   |                              ^^^^^ here
   |                      ^^^^^^^^^^^^^^^^^ in this pragma
   |              ^^^^ in this pragma
   |              ^^^^^ this contract
  --> axionc/tests/fixtures/contracts_reject.axi:2:14
  --> axionc/tests/fixtures/contracts_reject.axi:4:14
  --> axionc/tests/fixtures/contracts_reject.axi:7:31
  = help: a refinement compares Int expressions (`+ - *`, literals, `len a` of an array parameter) with `< <= > >= == /=`, joined by `&&`/`||`
  = help: a refinement compares Int expressions (`+ - *`, literals, `len a` of an array parameter) with `< <= > >= == /=`, joined by `&&`/`||`
  = help: see docs/contracts.md
  = help: see docs/contracts.md
  = help: see docs/contracts.md
  = help: write `{-# CONTRACT f requires <predicate> ensures <predicate> #-}`, with any number of `requires` and `ensures` clauses (see docs/contracts.md)
  = help: write `{-# CONTRACT f requires <predicate> ensures <predicate> #-}`, with any number of `requires` and `ensures` clauses (see docs/contracts.md)
  |
  |
  |
  |                               ^ here
  |              ^^^^^ this contract
  |              ^^^^^^ this contract
11 | {-# CONTRACT notint requires s > 0 #-}
15 | {-# CONTRACT nokw x > 0 #-}
19 | {-# CONTRACT badpred requires x > > 0 #-}
2 | {-# CONTRACT nosuch requires x > 0 #-}
24 | {-# CONTRACT twice ensures result > 0 #-}
4 | {-# CONTRACT nosig requires x > 0 #-}
7 | {-# CONTRACT badname requires y > 0 #-}
error[AX0601]: ill-formed refinement: `y` is not a parameter named in this signature
error[AX0601]: ill-formed refinement: only `Int` values can be refined
error[AX0603]: `nosig` needs a type signature to have a contract
error[AX0603]: `nosuch` is not a top-level function of this module
error[AX0603]: `twice` has more than one contract
error[AX0603]: malformed contract: expected `requires` or `ensures` after the function name
error[AX0603]: malformed contract: this predicate does not parse
