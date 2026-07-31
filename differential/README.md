# Differential tests — `axionc` vs the EDSL bench (GHC oracle)

> §17: "Own typechecker with linearity — **validated differentially against the
> Phase 0 EDSL prototype**."

Each subfolder is a **linearity scenario** with the same expected verdict from
two independent checkers:

- `prog.axi` — run by `axionc` (`--check`): accepts (exit 0) or rejects
  (exit ≠ 0, with `AX0001`/`AX0002`).
- `Prog.hs` — run by **GHC** through the Phase 0 EDSL bench (imports
  `Axion.Prototype.Buffer`): accepts (compiles) or rejects (multiplicity error).
- `expected` — the shared verdict: `accept` or `reject`.

The runner [`../scripts/differential.sh`](../scripts/differential.sh) requires
**both** to agree with `expected`. This is what anchors `axionc`'s linearity
checker to the GHC oracle: the same language invariant, two implementations, one
verdict.

| Scenario | Idea | Verdict |
|----------|------|---------|
| `01_consume_once` | `%1` resource consumed exactly once | `accept` |
| `02_consume_twice` | contraction: `%1` used twice (`AX0001`) | `reject` |
| `03_drop_unused` | must-use (`Token`) dropped without consuming (`AX0002`) | `reject` |

> **Note (Auto-Drop, Phase 2).** Scenario `03` uses a **must-use** type
> (`Token`) on purpose: a *droppable* type would be accepted by `axionc` via
> Auto-Drop (the compiler injects `free`), but GHC would reject it all the same
> (`LinearTypes` treats every linear value as must-use, with no Auto-Drop).
> Restricting the scenario to must-use keeps the two checkers in agreement.
