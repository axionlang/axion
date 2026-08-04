  |
  |
3 | bad = putStrLn "hi"
3 | bad = putStrLn "hi"
  --> axionc/tests/fixtures/type_mismatch.axi:3:1
  --> axionc/tests/fixtures/type_mismatch.axi:3:1
error[AX0200]: type mismatch: IO () vs Int
error[AX0200]: type mismatch: IO () vs Int
  | ^^^^^^^^^^^^^^^^^^^ expected IO (), found Int
  | ^^^^^^^^^^^^^^^^^^^ expected IO (), found Int
  = help: inference required these two types to be equal; check the signature and the arguments of the application.
  = help: inference required these two types to be equal; check the signature and the arguments of the application.
