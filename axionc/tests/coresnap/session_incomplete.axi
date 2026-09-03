  --> axionc/tests/fixtures/session_incomplete.axi:3:1
  = help: carry the endpoint to `close`, or consume it with `offer`/`cancel`.
  |
  | ^^^^^^^^^^^^^^^^^^ incomplete protocol here
3 | worker chan = do
error[AX0301]: endpoint 'c2' did not complete its session protocol (it must be consumed up to `close`)
