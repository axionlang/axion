# Phase 0 — Decisions and foundations (checklist)

> §17 of the spec. "Fix scope and infrastructure before a single line of compiler."
> The Haskell code is a **throwaway semantic-validation bench**, not the embryo of
> the compiler. The real `axionc` (Rust) is born in Phase 1 (§18).

## Phase 0 steps (§17)

- [x] **Key decision (strategy).** EDSL over Linear Haskell (`LinearTypes` +
  `linear-base`) to validate the semantics in weeks — throwaway prototype.
  Recorded in project memory; see also [`../README.md`](../README.md).
  - **Bench limits** (assumed): the EDSL only validates the `%1` core (L0/L1).
    `%0.5`, `&`, `~` and session types are **not** expressible in GHC's
    `LinearTypes` (multiplicities on arrows only) → Phase 3 (formal trail) +
    the compiler's own typechecker.
- [x] **`git init`, Cabal project, CI, formatter, linter.**
  - git repo initialized; spec versioned alongside the code in [`../spec`](../spec).
  - Cabal project: [`../axion-prototype.cabal`](../axion-prototype.cabal) (lib +
    exe + test-suite).
  - Reproducible dev shell (NixOS): [`../flake.nix`](../flake.nix).
  - CI: [`../.github/workflows/ci.yml`](../.github/workflows/ci.yml).
  - Formatter: `fourmolu` ([`../fourmolu.yaml`](../fourmolu.yaml)).
    Linter: `hlint` ([`../.hlint.yaml`](../.hlint.yaml)).
- [x] **Minimal grammar (L0/L1) + target programs.**
  - Grammar: [`grammar.md`](grammar.md).
  - 5 target programs: [`../examples`](../examples).
- [x] **Spec versioned alongside the code.** [`../spec`](../spec).

## The first 2 weeks (§17) — state

- [x] `git init` + the EDSL prototype's Cabal project with `LinearTypes` enabled.
- [x] Write the 5 target Axion programs that define "Phase 1 success"
  ([`../examples`](../examples)).
- [x] EDSL prototype: a `Buffer %1` that the typechecker refuses to use twice.
  - Positive: [`../prototype/src/Axion/Prototype/Buffer.hs`](../prototype/src/Axion/Prototype/Buffer.hs)
    + [`Examples.hs`](../prototype/src/Axion/Prototype/Examples.hs) — compiles and runs.
  - Negative: [`../prototype/test/negative/UseTwice.hs`](../prototype/test/negative/UseTwice.hs)
    — **does not compile by design**; `scripts/check-negative.sh` requires the failure.
- [x] Set up CI + the property-test structure (the scaffold, not the tests yet).
  - `tasty` + `tasty-quickcheck`: [`../prototype/test/Spec.hs`](../prototype/test/Spec.hs).
- [x] Stable error-code registry seeded (§8, done early on purpose):
  [`error-codes.md`](error-codes.md) — `AX0001`–`AX0003`.

## Verification (everything runs in the flake dev shell)

```sh
nix develop --command cabal build all               # builds lib+exe+test
nix develop --command cabal run -v0 axion-prototype # prints the checksum (42) and the byte (7)
nix develop --command cabal test                    # 3 tests: 2 unit + 1 property (100 cases)
nix develop --command ./scripts/check-negative.sh   # REQUIRES that Buffer %1 used 2× fails (AX0001)
nix develop --command fourmolu --mode check prototype
nix develop --command hlint prototype
```

Current state: **build ✅ · run ✅ · test ✅ · negative ✅ · fourmolu ✅ · hlint ✅**
(GHC 9.8.4, `linear-base` 0.4.0).

## What does NOT belong to Phase 0 (avoid scope creep)

- Own parser / typechecker / backend → **Phase 1** (in Rust, from scratch).
- Auto-Drop, arenas, `%0.5`, benchmarks → **Phase 2**.
- Channels, session types, M:N runtime, formal trail → **Phase 3**.
- LSP, `--explain`, playground, enforced L0–L3 levels → **Phase 4**.
- `TritVec` (ternary), `~`/`Maybe~` (advanced topology) → **Phase 5a/5b**.
