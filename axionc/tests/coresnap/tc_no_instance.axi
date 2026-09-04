  --> axionc/tests/fixtures/tc_no_instance.axi:4:8
  = help: declare `instance Eq Foo where …`, or use a type that has an instance of this class.
  |
  |        ^^ method used here, over this type
4 | main = eq Foo Foo
error[AX0404]: no instance of `Eq` for `Foo`
