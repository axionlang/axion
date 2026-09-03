  --> axionc/tests/fixtures/session_offer_incomplete.axi:5:1
  --> axionc/tests/fixtures/session_offer_incomplete.axi:5:12
  = help: add an arm for each label of the `Offer` (incl. `Closed`, the cancellation — §7/T5).
  = help: add the missing constructor arm(s), or a `_` wildcard catch-all.
  |
  |
  |            ^^^^^^^^^^ this `case` does not cover every constructor
  | ^^^^^^^^^^^^^^^^^^^^^ unhandled session branch
5 | worker d = case offer d of
5 | worker d = case offer d of
error[AX0202]: non-exhaustive patterns: Closed not covered
error[AX0304]: the `case offer d` does not handle branch 'Closed' of the external choice (the session offers it)
