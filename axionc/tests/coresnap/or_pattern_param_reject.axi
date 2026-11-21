  --> axionc/tests/fixtures/or_pattern_param_reject.axi:3:22
  |
  |                      ^ unexpected here
3 | f (Just 1 | Nothing) = 1
error[AX0100]: syntax error: expected one pattern (an or-pattern `|` is allowed only in a `case` arm; write a `case` here), found Equals
