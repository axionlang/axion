# Phase 1 — Walking skeleton (L0/L1 core) (checklist)

> §17 of the spec. "The minimal compiler that runs a linear program." Principle #1:
> it doesn't ship a feature, but `parse → typecheck → run` end-to-end on a minimal
> subset. Everything grows from there. `axionc` is written **from scratch in Rust**
> (§18); the Phase 0 EDSL bench (`../prototype`) remains as a semantic oracle.

## Phase 1 steps (§17)

- [x] **Parser for the minimal subset** (types, functions, `let`, `%1`).
  `axionc/src/{lexer,layout,parser}.rs`. Covers L0/L1: signatures with `%1`,
  clauses with pattern matching, `where`, `let`/`in`, `case`, `if`, application,
  arithmetic. See [`grammar.md`](grammar.md).
- [x] **Stable error codes + structured diagnostics (JSON)** from the very first
  error (§8). `axionc/src/diag.rs`; registry in [`error-codes.md`](error-codes.md).
  `--emit json` and `--explain AXnnnn`.
- [x] **Own typechecker with linearity.** `axionc/src/check.rs`: name resolution
  (`AX0101`) + linearity analysis (`AX0001` use-after-consume, `AX0002` dropped
  without consuming). It is the same invariant validated in the Phase 0 bench
  (`../prototype/test/negative/UseTwice.hs`).
  - **Validated by differential** against the GHC oracle: `differential/` +
    `scripts/differential.sh` run each scenario in both checkers and require the
    same verdict. State: 3 scenarios, full agreement.
- [x] **Type inference (HM / Algorithm W).** `axionc/src/infer.rs`: type
  variables, unification with occurs-check, schemes, generalization in `let`/`where`,
  builtin types, records (construction/update/selectors). Runs alongside linearity;
  emits `AX0200` (mismatch) and `AX0201` (infinite type). Functions with a signature
  are checked in *checking* mode (parameters inherit the declared types).
- [x] **Lower to a backend: own interpreter** (the future `--dev` fast-path).
  `axionc/src/interp.rs` (tree-walking). Native backend (Cranelift/LLVM) is left for
  the next phase.
- [~] **Goal:** "Listing 2.1 compiles and runs; a use-after-consume is rejected.
  Property tests checking preservation/progress."
  - Use-after-consume rejection: **done** (`AX0001`), incl. over records
    (`tests/fixtures/record_use_twice.axi`).
  - Running programs: **done** for `examples/01_hello.axi`, `02_fib.axi`, and
    records (`tests/fixtures/record_run.axi`: construction, update, selector).
  - **Listing 2.1 (`examples/04`) compiles** (`--check`): `data`/records with a
    linear `%1` field, record update `p { status = ... }`, a `Process %1` param
    consumed once. It doesn't *run* because it has no `main` and uses a native
    `Buffer` (Phase 2); the record semantics are validated by `record_run.axi`.
  - **Preservation/progress property tests: done.** `axionc/src/props.rs` generates
    well-typed terms by construction (Int/Bool: arithmetic, comparisons, `if`,
    `let`+variables) and checks, over 4000 random terms: (1) the typechecker accepts
    them, (2) they evaluate without getting stuck (**progress**), (3) the value has
    the static type (**preservation**). Non-vacuity confirmed by mutation.

## Verification

```sh
cd axionc
cargo test                                  # integration tests
cargo run -- ../examples/01_hello.axi        # Hello, Axion!
cargo run -- ../examples/02_fib.axi          # 832040
cargo run -- --check tests/fixtures/use_after_consume.axi   # AX0001, exit 1
cargo run -- --check tests/fixtures/use_once_ok.axi         # OK, exit 0
```

State: **walking skeleton ✅** (parse→typecheck→run + linearity rejection). GHC is
not needed here — `axionc` is pure Rust (`cargo`).

## What comes next within Phase 1 (growing the skeleton)

- `data`/records + the complete Listing 2.1 (`%1` field, in-place mutation).
- Type inference (HM) beyond linearity checking.
- Preservation/progress property tests (the scaffold exists in the Phase 0 bench).
- Differential against the EDSL bench: same programs, same verdict.

## What is left for later phases (avoid scope creep)

- Auto-Drop, arenas, `%0.5`, benchmarks → **Phase 2**.
- `salsa` (incremental) + `rowan` (lossless CST) + LSP → **Phase 4/8**.
- Native Cranelift (`--dev`) / LLVM (`--release`) backend → **Phase 2+**.
