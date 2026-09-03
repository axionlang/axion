  --> axionc/tests/fixtures/level_exceeded.axi:3:1
  = help: L1 needs linear resources (`%1`/`%0.5`), arenas, or dense/compact arrays; raise the ceiling to `{-# LEVEL L1 #-}` or remove the feature
  |
  | ^ this uses L1 features
3 | f b = b
error[AX0500]: declaration `f` is L1 but this module's `{-# LEVEL L0 #-}` ceiling forbids it
