# Phase 3 — Concurrency: channels + session types (checklist)

> §17 of the spec. Isolated deliverable: **race-freedom and deadlock-freedom**.
> The guiding principle of this phase (§17): **"prove before building"** — the
> calculus is formalized *before* any code; the theory dictates the design.

## Formal trail (starts BEFORE the code)

- [x] **Session calculus (ASC)** — syntax, duality, typing, asynchronous
  operational semantics, and the theorems T1–T5 (preservation, progress, session
  fidelity, deadlock-freedom, cancellation). Basis: *Propositions as Sessions*
  (Wadler) + **GV/EGV** (Fowler et al., POPL 2019, for panic). See
  [`docs/phase-3-calculus.md`](phase-3-calculus.md). **Cut elimination = the acyclic
  tree the `bound` enforces** — deadlock-freedom is a corollary of typing.
- [x] **Configuration interpreter** (executable reference of the calculus) +
  **property tests** of T1–T5 over generated protocols. `axionc/src/session.rs`:
  models threads (defunctionalized continuations) + asynchronous buffers + the
  `spawn` tree; a deterministic generator produces well-typed protocols by
  construction (one side `S`, the other `dual S`) in a tree. Tests: T1 (involutive
  duality), T2/T3/T4 (2000 trees run without deadlock, fidelity intact), T5 (injected
  panic drains via `Closed`, no orphans). **Non-vacuity proven**: two detector tests
  confirm the interpreter catches a real cyclic deadlock and a fidelity violation. It
  is the oracle for the production typechecker.
- [x] **CFSM model-checking** — projection of each session onto a communicating
  machine (the state is the remaining session; transitions `!`/`?`); the dual forms
  the system with two FIFO channels. **Exhaustive** exploration of the global state
  space (`axionc/src/session.rs`): checks deadlock-freedom, compatibility (no
  unspecified reception) and absence of orphans. Coverage: **all** sessions up to
  depth 3 (>1000 protocols) + a random sample at depth 6. Non-vacuity: detectors
  confirm it catches cyclic deadlock, orphan and unspecified reception on non-dual
  pairs. Complements the random test with state coverage.
- [x] **Surface→ASC differential** — `session.rs::from_surface_type` translates the
  surface session type (extracted from each fixture by the real lex→layout→parse
  pipeline) to the ASC `Session`; `surface_sessions_agree_with_asc_cfsm_oracle` runs
  the (exhaustive) CFSM model-checker over each, requiring `Ok`. It anchors the
  session typechecker (AX0300–AX0305) to the proven reference, as GHC anchors
  linearity. **Missing:** the program level (`bound`/`spawn` skeleton → Config →
  reference interpreter).

## Implementation (after the trail)

- [~] **Session frontend/typechecker** — v1 done: `send`/`recv`/`close` typed in
  `infer.rs` (permissive) + consumed in linearity; the `check_sessions` pass
  (`check.rs`) checks **protocol fidelity** (the operation follows the endpoint's
  session type, **AX0300**) and **completeness** (the endpoint reaches `close`,
  **AX0301**), over the linear spine of `do`/`let`. `do`-binds with a tuple pattern
  (`(x, c) <- recv c`) in the parser. Accept + AX0300 + AX0301 fixtures. **Nursery
  confinement done** (`check_bound_escapes`): an endpoint created in a `bound` (by
  `newChannel`/`spawn`/`send`/`recv`) cannot be returned from the block — **AX0302**,
  the analog of sub-arena escape (AX0003) but without a `promote` escape hatch. It is
  the **structural deadlock-freedom** of §9 (the communication graph becomes a tree)
  enforced in the compiler. Fixtures `bound_ok` (accepted) + `bound_escape` (AX0302).
  **Choice done** (`⊕`/`&`): `select L c` advances by the chosen label of a `Select`
  (AX0300 if the label doesn't exist); `offer c` consumes an external choice; and
  **AX0303** requires every `Offer` to include the `Closed` branch — cancellation
  exhaustiveness (T5/§7). Session types with labeled branches via
  `Select (L1 S1) (L2 S2) …`. Fixtures select_ok/bad + offer_ok/no_closed.
  **Exhaustiveness + tree closed:** **AX0304** — the `case offer c of {…}` must
  handle all branches of the `Offer` (incl. `Closed`), following each arm with its
  continuation; **AX0305** — the `spawn` closure cannot capture endpoints from
  outside (only its parameter), guaranteeing that each spawn creates a parent↔child
  edge (tree → deadlock-free, §9). **Missing:** delegation (endpoints over channels
  between siblings, acyclic pipelines). *(Surface→ASC differential at the type level:
  done, see above.)*
- [~] **Scheduler runtime (§11)** — 1st cut in the interpreter (the `--dev`
  fast-path): a **single-thread cooperative scheduler** in `interp.rs` runs
  `bound`/`spawn`/channel programs. Tasks are "defunctionalized continuations" —
  literally the remaining `Expr` of the `do` (the chain of `case`); the only
  suspension point is a `recv` on an empty buffer (task switch); the `Value`s (Rc)
  stay on a single thread (no `Send`). `Value::Endpoint`,
  `newChannel`/`spawn`/`send`/`recv`/`select`/`close` executable.
  `session_run_pingpong.axi` runs a concurrent ping-pong (21→42). **Choice and
  cancellation running:** `select L c` sends the label; `case offer c of { L d -> … }`
  receives it and dispatches (a tagged sum value `L (Ep …)` carries the advanced
  endpoint); `cancel c` sends `Closed` to the peer, which `offer` receives as the
  cancellation branch (T5/§7 running). `session_run_offer.axi` (→7),
  `session_run_cancel.axi` (→5). **Missing:** real M:N with work-stealing +
  `io_uring`/`epoll` (nursery arena, the full §11) in the native backend.
- [ ] **Panic cancellation (§7)** — Linear Unwinding: O(1) sub-arena `reset`,
  `Closed` to the peer in O(children), `@cleanup` once (T5).
- [ ] **Surface sugar (§9)** — `A ~ B`, `A Maybe~ B`, `observe`,
  `makeCoupledPair`, `parMap`, the `|>` telescope — normative desugaring to the ASC
  linear endpoints.

## Metatheory (medium term)

- [ ] **Iris/Actris** — T1–T5 mechanized in separation logic.
- [ ] **Reference verifier** (translation validation) — cross-check of the
  typechecker's decisions at compile time; zero runtime cost.

## Phase goal

`bound arena $ do …` runs concurrent workers without data races or deadlocks,
proven by types; a panic recovers in O(1) without leaks or orphan endpoints.
