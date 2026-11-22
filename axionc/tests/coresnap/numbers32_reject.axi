   --> axionc/tests/fixtures/numbers32_reject.axi:13:9
   --> axionc/tests/fixtures/numbers32_reject.axi:17:12
   |
   |
   |            ^^^^^^^^^ method used here, over this type
   |         ^ expected Float32, found Int
  --> axionc/tests/fixtures/numbers32_reject.axi:5:10
  --> axionc/tests/fixtures/numbers32_reject.axi:9:13
  = help: an `Int32` holds 32 bits; use an `Int`, or `toInt32 n` to keep the low 32 bits of a larger value
  = help: declare `instance Integral Float32 where …`, or use a type that has an instance of this class.
  = help: inference required these two types to be equal; check the signature and the arguments of the application.
  = help: inference required these two types to be equal; check the signature and the arguments of the application.
  |
  |
  |             ^^^^^ expected Int32, found Int
  |          ^^^^^^^^^^ outside -2147483648 … 2147483647
13 | whole = 1
17 | fdiv a b = a `div` b
5 | tooBig = 3000000000
9 | mixed a b = a + b
error[AX0200]: the literal 3000000000 does not fit in an `Int32`
error[AX0200]: type mismatch: Float32 vs Int
error[AX0200]: type mismatch: Int32 vs Int
error[AX0404]: no instance of `Integral` for `Float32`
