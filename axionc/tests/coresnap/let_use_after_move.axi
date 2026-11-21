   --> axionc/tests/fixtures/let_use_after_move.axi:10:44
   --> axionc/tests/fixtures/let_use_after_move.axi:19:12
   |
   |
   |
   |
   |                                            ^ 's' used here…
   |                                 ^ …but ownership had already been moved here
   |                       ^ …but ownership had already been moved here
   |            ^ 's' used here…
  = help: after moving a %1 (consuming), you cannot read or consume it again — ownership has left this scope (§2).
  = help: after moving a %1 (consuming), you cannot read or consume it again — ownership has left this scope (§2).
  = rule: R6 (docs/spec.md#r6)
  = rule: R6 (docs/spec.md#r6)
10 | inLet n = let s = show n in eat s + strLen s
10 | inLet n = let s = show n in eat s + strLen s
18 |   putStrLn (show (eat s))
19 |   putStrLn s
error[AX0004]: use of 's' after ownership was moved
error[AX0004]: use of 's' after ownership was moved
