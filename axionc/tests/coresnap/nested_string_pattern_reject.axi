  --> axionc/tests/fixtures/nested_string_pattern_reject.axi:5:9
  = help: bind the field to a variable and compare it in a nested `case` (`Just s -> case s of "a" -> …`)
  |
  |         ^^^ inside another pattern here
5 |   Just ("a") -> "ab"
error[AX0204]: a string-literal pattern must be a whole `case` arm's pattern
