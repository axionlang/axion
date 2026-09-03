  --> axionc/tests/fixtures/float_type_mismatch.axi:2:13
  --> axionc/tests/fixtures/float_type_mismatch.axi:2:8
  = help: inference required these two types to be equal; check the signature and the arguments of the application.
  = help: inference required these two types to be equal; check the signature and the arguments of the application.
  |
  |
  |             ^ expected Float, found Int
  |        ^ expected Float, found Int
2 | main = 3 +. 2
2 | main = 3 +. 2
error[AX0200]: type mismatch: Float vs Int
error[AX0200]: type mismatch: Float vs Int
