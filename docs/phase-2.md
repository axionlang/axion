# Phase 2 — Memory model (the differentiator) (checklist)

> §17 of the spec. "What makes Axion ≠ just another Haskell": memory safety
> **without GC**. Built in increments, each tested and committed.

## Pillars (§17)

- [~] **Auto-Drop** — a *liveness* analysis that inserts `free` at the death point
  (§2). **Fine liveness done** (`axionc/src/check.rs`):
  - **Borrow vs consumption** (Borrow Elision, §2): *reading* a `%1` is free and
    unlimited; *consuming* (a `%1` arg, `%1` field, return) is at most once. The
    position of each occurrence decides. Hence: consumptions >1 ⇒ `AX0001`;
    consumptions ==0 and must-use ⇒ `AX0002`; consumptions ==0 and droppable ⇒
    Auto-Drop; ==1 ⇒ ownership transferred, no drop.
  - **Fine death point**: the `free` is inserted at the **last read** (not "at
    entry"), or at entry if the resource is never read. `axionc --emit drops` shows
    the location and the reason (`dies after the last read` / `at entry`).
  - `examples/04` (Listing 2.1): `p` is consumed (record update) ⇒ **no** drop.
    `x + x` (two reads) ⇒ accepted, drop after the 2nd `x`. `(x, x)` (two
    consumptions) ⇒ `AX0001`.
  - **Order checked** (`AX0004` use-after-move): a traversal in evaluation order
    marks when `x` is moved; any later read/consumption is an error. `x + sink x`
    (reading before consuming) is accepted; `sink x + x` (reading after) is `AX0004`.
  - **Structural `Drop` propagation** (fixpoint): a `data` is must-use if some field
    (recursively) is — a record containing an `Ep`/`Token` cannot be auto-dropped
    (`AX0002`).
  - **`let`-value drops**: a `let v = <e that consumes a linear resource>` makes `v`
    a linear resource in its scope; if `v` is not consumed, Auto-Drop (droppable) or
    `AX0002` (must-use) — not just parameters.
  - **In-place mutation (Linear Elision)**: a record update whose base is a linear
    resource (its last live mention) is marked as in-place; `axionc --emit inplace`
    shows them (e.g. `04` → `p { status = … }`).
  - **To grow:** provenance through arbitrary function returns (only the direct move
    is followed); `where`-value binds; elision actually applied in the backend (for
    now it is analysis + report, not codegen).
- [~] **Arenas + NLL reset + escape analysis** (`promote`, §3). Listing 3.3–3.5.
  - **Lambdas** (`\x -> e`) added (parser, inference, check traversals); needed for
    `withSubArena parent (\sub -> …)`.
  - Typed arena builtins: `withSubArena :: Arena -> (Arena -> a) -> a`,
    `allocateCell :: Arena -> Cell`, `promote :: Arena -> Cell -> Cell` (the arena
    arg is borrowed — allocateCell/promote read it many times).
  - **Escape (`AX0003`)** — by **return** or by **closure capture** (§3C): region
    provenance trace; `promote parent v` cuts the provenance. `arena_escape.axi`
    (return) and `arena_capture.axi` (closure) → `AX0003`; `arena_promote_ok.axi` →
    accepted.
  - **NLL reset** (Fig. 3.1): the sub-arena reset is computed at the region's
    **death point** (the last live mention of a sub-arena value), not at the lexical
    end. `axionc --emit arenas` shows it (e.g. `arena_promote_ok` → reset after the
    last mention of `node`, at the promotion).
  - **`arena_mark`/`arena_release`** (intra-scope reclamation, Listing 3.6):
    `mark = arena_mark arena` saves the top of the bump-pointer; `arena_release mark`
    reclaims everything allocated after. An ordered analysis over the `let` spine
    rejects using, **after** the release, a value allocated under the mark (`AX0005`).
    `arena_mark_release.axi` → `AX0005`; `arena_mark_ok.axi` (use before the release)
    → accepted.
  - **Lambdas run** in the interpreter (`\x -> e` becomes a one-clause closure) —
    higher-order functions and currying work (`tests/fixtures/lambda_hof.axi`).
  - **Grown since:** the arena runtime itself now runs natively (see
    [`backend.md`](backend.md)); arenas remain statically validated.
- [x] **Fractional permissions** (`%0.5`): `split` / `join` (§2, Listing 2.3).
  - Tuple patterns `(a, b)` (parser/ast/infer/interp) to destructure the pair from
    `split`; tuples now have a runtime value.
  - Builtins: `split :: a -> (a, a)`, `join :: a -> a -> a` (the `%1`/`%0.5`
    multiplicities are tracked separately). `split` consumes the `%1`.
  - **Read-only (`AX0006`)**: `case (split …) of (a, b) -> arm` marks `a`/`b` as
    `%0.5` halves; writing them in the arm (arg of a `%1` parameter, base of an
    update, `%1` field) is `AX0006`. Reading them and recombining with `join` is
    accepted. `frac_write.axi` → `AX0006`; `frac_join.axi` → accepted **and runs**
    (→ 7).
  - **To grow:** must-use of the halves (each half must be recombined or dropped);
    `%0.5` in positions beyond `case split`.
- [~] **Benchmark vs baseline (C/Rust)** — **first measurement point** now that the
  `--dev` native backend (Cranelift) runs. `bench/` + `scripts/bench.sh`: `fib(40)`
  in Axion/C/Rust. Result: the `--dev` fast-path (no opt) already beats C/Rust `-O0`
  and lands ~2–3× off `-O2` — the gap `--release`/LLVM will close. See
  [`benchmarks.md`](benchmarks.md).

## Verification (Auto-Drop)

```sh
cd axionc
cargo test                                            # tests (including Auto-Drop)
cargo run -- --check tests/fixtures/drop_linear.axi   # Token must-use → AX0002
cargo run -- --check tests/fixtures/struct_mustuse.axi # record with Ep → AX0002 (structural)
cargo run -- --check tests/fixtures/let_leak.axi      # let must-use dropped → AX0002
cargo run -- --emit drops tests/fixtures/let_drop.axi # free(b2) — drop of a 'let' value
cargo run -- --emit inplace ../examples/04_process_inplace.axi  # 'p' mutated in-place
cargo run -- --check tests/fixtures/use_after_move.axi # sink x + x → AX0004
```

Differential: the `differential/02_consume_twice` scenario **moves** the `%1`
twice (`(x, x)`), it doesn't read it twice — reading would be accepted. The
`03_drop_unused` uses `Token` (must-use) on purpose: a droppable would be accepted
by Auto-Drop but GHC would reject it (it has neither Borrow Elision nor Auto-Drop).
Both restrictions keep `axionc` and GHC in agreement.

## Impact on the error registry

`AX0002` moved from "any unconsumed `%1`" to "only unconsumed **must-use**" —
droppable types are managed by Auto-Drop. See [`error-codes.md`](error-codes.md).
