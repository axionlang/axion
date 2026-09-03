  --> axionc/tests/fixtures/tc_unconstrained_method.axi:3:9
  = help: add `Eq a =>` to the function signature to allow the method over a generic type.
  |
  |         ^^ generic type here
3 | bad x = eq x x
error[AX0405]: class `Eq` method used over a polymorphic type without a constraint
