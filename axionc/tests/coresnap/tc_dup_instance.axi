  |
8 | instance Eq2 Int where
  | ^ an instance for this type already exists
  --> axionc/tests/fixtures/tc_dup_instance.axi:8:1
error[AX0403]: duplicate instance of `Eq2` for `Int`
  = help: each (class, type) pair may have only ONE instance — method resolution must be unambiguous (coherence).
