  --> axionc/tests/fixtures/session_spawn_capture.axi:7:15
  = help: a spawned child communicates with the parent only through its endpoint parameter (parent↔child edge); don't capture outside channels (§9, deadlock-freedom).
  |
  |               ^^^^^^^^^^^^^^ endpoint capture forbidden
7 |   c <- spawn (\d -> send a 1)
error[AX0305]: the `spawn` closure captures endpoint 'a' from outside — it would break the nursery's tree topology
