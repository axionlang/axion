  |
8 |   d
  --> axionc/tests/fixtures/bound_escape.axi:8:3
error[AX0302]: an endpoint escapes the `bound` nursery
  = help: endpoints are born confined to the `bound` so the communication graph is a tree (deadlock-freedom, §9); consume them inside the block (`close`/`send`/`recv`), don't return them.
  |   ^ returned from here — the endpoint would outlive the nursery
