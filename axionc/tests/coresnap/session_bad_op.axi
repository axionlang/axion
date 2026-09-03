  --> axionc/tests/fixtures/session_bad_op.axi:5:14
  = help: the operation must follow the endpoint's session type: `send` on a `Send`, `recv` on a `Recv`, `close` on an `End`, and the label of `select` must belong to the `Select`.
  |
  |              ^^^^^^^^^ invalid session operation
5 |   (x, c2) <- recv chan
error[AX0300]: `recv` on endpoint 'chan' does not follow the protocol: expected a `Recv`, but it is at `Send`
