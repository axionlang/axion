  |
4 | handler c = offer c
  --> axionc/tests/fixtures/session_offer_no_closed.axi:4:1
error[AX0303]: the external choice (`Offer`) of endpoint 'c' has no `Closed` branch — cancellation of a panicking peer would go unhandled (§7)
  = help: add a `Closed` branch to the `Offer` (it is the label that Linear Unwinding sends when cancelling — T5).
  | ^^^^^^^^^^^^^^^^^^^ missing the `Closed` branch
