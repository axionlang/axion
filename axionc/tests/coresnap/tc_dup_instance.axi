  --> axionc/tests/fixtures/tc_dup_instance.axi:8:1
  = help: each (class, type) pair may have only ONE instance — method resolution must be unambiguous (coherence).
  |
  | ^ an instance for this type already exists
8 | instance Eq2 Int where
error[AX0403]: duplicate instance of `Eq2` for `Int`
