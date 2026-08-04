  |
  |
7 |     let node = allocateCell sub in
8 |     \x -> node)
  --> axionc/tests/fixtures/arena_capture.axi:8:5
error[AX0003]: a value escapes its sub-arena
  = help: on reset the sub-arena's RAM is reclaimed; move the value to the parent arena before the reset with 'promote parent value' (§3).
  |                ^^^^^^^^^^^^^^^^ lives in sub-arena 'sub'
  |     ^^^^^^^^^^ returned from here — it would outlive the sub-arena reset
