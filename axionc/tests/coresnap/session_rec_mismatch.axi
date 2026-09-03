  --> axionc/tests/fixtures/session_rec_mismatch.axi:8:1
  = help: the endpoint passed to the recursive call must be at the same session state as the function's parameter.
  |
  | ^ session recursion type mismatch
8 | worker d = case offer d of
error[AX0300]: recursive call `worker d3` does not continue the session protocol of 'd3' (its type here is not `worker`'s parameter type)
