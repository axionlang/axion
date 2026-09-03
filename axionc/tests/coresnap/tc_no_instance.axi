  --> axionc/tests/fixtures/tc_no_instance.axi:3:8
  = help: declare `instance Eq String where …`, or use a type that has an instance of this class.
  |
  |        ^^ method used here, over this type
3 | main = eq "a" "b"
error[AX0404]: no instance of `Eq` for `String`
