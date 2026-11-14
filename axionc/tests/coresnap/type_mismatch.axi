  --> axionc/tests/fixtures/type_mismatch.axi:3:1
  = help: inference required these two types to be equal; check the signature and the arguments of the application.
  |
  | ^^^^^^^^^^^^^^^^^^^ expected IO (), found Int
3 | bad = putStrLn "hi"
error[AX0200]: type mismatch: IO () vs Int
