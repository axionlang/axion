  |
3 | bad x = eq x x
  --> axionc/tests/fixtures/tc_unconstrained_method.axi:3:9
error[AX0405]: class `Eq` method used over a polymorphic type without a constraint
  |         ^^ generic type here
  = help: add `Eq a =>` to the function signature to allow the method over a generic type.
