  |
7 |   c <- spawn (\d -> send a 1)
  --> axionc/tests/fixtures/session_spawn_capture.axi:7:15
  |               ^^^^^^^^^^^^^^ endpoint capture forbidden
error[AX0305]: the `spawn` closure captures endpoint 'a' from outside — it would break the nursery's tree topology
  = help: a spawned child communicates with the parent only through its endpoint parameter (parent↔child edge); don't capture outside channels (§9, deadlock-freedom).
