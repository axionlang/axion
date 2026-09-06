  --> axionc/tests/fixtures/string_case_no_catchall.axi:3:7
  |
  |       ^ string patterns are never exhaustive on their own
3 | f x = case x of
error[AX0204]: a `case` with string-literal patterns must be `"lit" -> …` arms followed by exactly one catch-all (`_` or a variable)
