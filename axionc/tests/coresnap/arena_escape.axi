  |
  |
4 | escapes parent = withSubArena parent (\sub -> let node = allocateCell sub in node)
4 | escapes parent = withSubArena parent (\sub -> let node = allocateCell sub in node)
  --> axionc/tests/fixtures/arena_escape.axi:4:78
error[AX0003]: a value escapes its sub-arena
  = help: on reset the sub-arena's RAM is reclaimed; move the value to the parent arena before the reset with 'promote parent value' (§3).
  |                                                          ^^^^^^^^^^^^^^^^ lives in sub-arena 'sub'
  |                                                                              ^^^^ returned from here — it would outlive the sub-arena reset
