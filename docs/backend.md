# Native backend — the `--dev` "Fast-Path" (Cranelift)

> §11/§18 of the spec. The pipeline lowers the AST to the **Axion Core IR** (ANF,
> strict/linear — see `axionc/src/core.rs`) and from there emits native code:
> **Cranelift in `--dev`** (compiles fast — "zero optimizations in dev") and
> **LLVM in `--release`** (`axionc --release`; lowers the same Core to textual LLVM
> IR and compiles with `clang -O2 -flto` + a small C runtime — on par with C, see
> [benchmarks](benchmarks.md)). Both share the same Core and cover the **same
> subset** (Int, records/tuples, strings/IO, `case`, closures, arenas, Auto-Drop,
> typeclasses via monomorphization, higher-order + partial application via
> eta-expansion). See the Core with `axionc --emit core` and the LLVM IR with
> `axionc --emit llvm`.

This `--dev` backend, over `cranelift-jit`, is a **plain Core→Cranelift emitter**:
multi-clause desugaring, `where` *lifting* and closure conversion have already
happened in the AST→Core lowering, so codegen only walks the ANF.

## What compiles (Int core)

- Top-level functions with an `Int` signature (params + return), **multi-clause**
  with variable/`_`/**literal** patterns — desugared into an `if` chain (requires a
  catch-all clause at the end). E.g. `fib 0 = 0; fib 1 = 1; fib n = …`.
- **`where`**: locals (e.g. `go`) are *lifted* to native functions with a mangled
  name (`fibFast$go`) and compiled, with recursion and mutual recursion.
- `if … then … else …`, arithmetic (`+ - *`, `mod`), comparisons (`== < >`).
- Calls to other native functions, **including recursion**.
- `let v = <Int> in …`.
- **Strings / IO** (via a minimal runtime): string literals (data objects,
  C-strings), `show :: Int -> String` (`axion_show_int`), `putStrLn`/`putStr :: String
  -> IO ()` (`axion_puts`/`axion_put`), and do-block sequencing + `mapM_`. So
  `main :: IO ()` runs natively — including the **real examples**
  `examples/01_hello.axi` ("Hello, Axion!"), `examples/02_fib.axi` ("832040"), and
  `examples/03b_fizzbuzz.axi` (via `mapM_ (putStrLn . fizzbuzz)`), with the same
  output as the interpreter.
- **Records** and **tuples** on the heap (`axion_alloc`): construction
  `Con { f = … }` / `(a, b)`, update `r { f = … }` (allocates and copies) and
  selectors `f r` (offset load); each field/component is an `i64`. Functions with
  `data`-typed params/return (pointer) compile. `record_run.axi` runs native (→ 99).
- **`case`**: an `if` chain over the scrutinee; `Int` patterns (compare),
  variable/`_` (catch-all), and tuple `(a, b)` (destructure by offset). Requires a
  catch-all at the end. `native_case.axi` runs native and equal to the interpreter.
- **Closures** (lambdas + higher-order functions): each `\p -> body` is *lifted* to
  a native function with ABI `(env, params…)`, which loads the captured variables
  from `env`. At the lambda site the environment `{fn_ptr, captures…}` is built on
  the heap (`axion_alloc`); function types are the pointer to that environment.
  Applying a function value (an `Int -> Int` parameter, or a lambda applied
  directly) is done via `call_indirect` over `env[0]`, with the closure itself
  passed as env. `native_closure.axi` runs native (→ 42) and equal to the
  interpreter (incl. multiple captures and nested application).
- **First-class functions** (higher-order + partial application): a top-level
  function/builtin used as a value, or partially applied (`compose g h`), is
  **eta-expanded** into a lambda (`\v -> f v`) — reusing the closure machinery.
  So `map succ xs`, `mapM_ greet xs` and `compose`/sections compile natively.
- **Typeclasses**: method calls over statically-concrete types are resolved to the
  instance impl, and constrained functions (`C a =>`) are **monomorphized** per
  type (`count$Int`, `eq$Int`) — zero-cost, à la Rust. See
  [benchmarks](benchmarks.md).

## How to use

```sh
# dumps the Cranelift IR of the compilable functions
axionc --emit clif program.axi

# JIT-compiles the Int core and runs 'main :: Int', printing the result
axionc --backend cranelift program.axi
```

Example (`axionc/tests/fixtures/native_fib.axi`):

```
fib :: Int -> Int
fib n = if n < 2 then n else fib (n - 1) + fib (n - 2)

main :: Int
main = fib 20
```

`axionc --backend cranelift native_fib.axi` → `6765` (real machine code, via JIT).
`--emit clif` shows the IR (blocks, `brif`, recursive `call`).

## What still does NOT compile (falls back to the interpreter)

- Sessions/concurrency (`spawn`/`send`/`recv`/`close`) and arenas' interpreter
  fallbacks: sessions are interpreter-only (the native concurrency road is future
  work).
- Constructor patterns in multi-clause function heads (`eq Red Red = …`) — write
  the instance with `case` for native.
- Functions (and `case`) **without** a catch-all at the end (the exhaustion *trap*
  is missing).
- Over-application (functions that return functions and are re-applied).
- Strings beyond `putStrLn`/`putStr`/`show` (concatenation, `String` as a
  parameter, …).

The transitive native-candidacy analysis excludes gracefully whatever doesn't
compile; for those programs, use the interpreter (`axionc program.axi`, no
`--backend`).

## Auto-Drop at runtime (reclamation, §2)

The heap is no longer all *leaked*: `axion_alloc` prefixes each block with a size
header and `axion_free` releases it. The reclamation analysis (in `core.rs`)
inserts `drop x` nodes into the Core that free the objects the function **owns** at
their death point. An object is *droppable* if it is **owned** — allocated locally
(`MakeTuple`/`MakeRecord`/`UpdateRecord`/`MakeClosure`), the result of a call that
returns heap (`data`/tuple), or a `%1` heap-typed parameter — and it **never
escapes** (returned, embedded, passed to a call, or aliased). `if`/`case` are
balanced to free once per path, and the scrutinee of a `case` is freed at the head
of each arm.

This gives **cross-function reclamation** for linear values: whoever returns heap
transfers ownership to the caller (who frees it), and a `%1` parameter is owned and
freed by the callee. Ownership sovereignty is the key to soundness — the linear
discipline guarantees no aliasing (`%1` cannot be duplicated), so freeing after the
last read is never use-after-free nor double-free.

See it with `--emit core` (`drop` nodes) and measure with `AXION_HEAP_STATS=1`
(prints `allocs`/`frees`):

- `heap_loop.axi` (300 calls allocating+freeing a tuple) → **300==300**, constant
  memory, no GC.
- `linear_move.axi` (`make` allocates a `Box`, `take` receives it by `%1`) →
  **1==1**: the object crosses the boundary and is freed once.

## Arenas at runtime (§3)

Arenas now run natively (they used to be `--check`-only). `Arena`/`Cell`/`Mark`
are `i64` (handles). The runtime is a **bump-allocator** by fixed chunks (stable
pointers): `withArena (\a -> …)` creates the root arena, runs the body and
**resets it in bulk** at the end (drops all chunks at once — no per-cell `free`);
`withSubArena` does the same for a sub-arena; `allocateCell` bump-allocates;
`promote` copies a cell to the parent arena (saves it from the reset);
`arena_mark`/`arena_release` save/restore the bump-pointer (intra-scope
reclamation). See it with `--emit core` (`withArena`, `allocateCell`, …) and
measure with `AXION_HEAP_STATS=1` (line `arena: N news, M resets, K cells`):
`arena_run.axi` (100 cells) → **100 cells, 1 reset**.

**Reset safety is free**: the static escape analysis (`AX0003`, `AX0005`) already
rejects, at compile time, returning/capturing a value that lives in an arena about
to be reclaimed (only `promote` saves it), so resetting at the end of the scope is
never use-after-reset.

**Still not reclaimed (conservative — safe):** **unrestricted** (`Many`) values
passed between functions — they can be aliased, so ownership isn't enough (they
need linear discipline or RC/GC); **closures** (they can be called). The
interpreter still doesn't run arenas (for them, native is the only runner).

Codegen refuses what doesn't fit with a clear error; for those programs, use the
interpreter (`axionc program.axi`, no `--backend`).

## Implementation notes

- `axionc/src/codegen.rs`: `JITModule` (cranelift-jit) + `FunctionBuilder`.
  Declares all native functions first (so recursion/mutual calls resolve), then
  defines the bodies; `Int` → `i64`; comparisons → `icmp`; `if` → two blocks + a
  join block with a parameter.
- The AST→Core lowering (`core.rs`) is in **ANF**: each compound subexpression is
  named by a `let`, arguments are atoms, and control (`if`/`case`) lives in an
  `Rhs` (a `let` can bind the result of a branch). Structural Drop is already an
  **explicit node** in the Core (`drop x`); arena reset and in-place remain implicit
  (computed by `check.rs`).
- The `--release` backend (LLVM, `axionc/src/llvm.rs`) lowers from the **same
  Core**, without duplicating the AST→IR lowering — it is what closes the `-O2`
  benchmark gap.

## Memory verification (sanitizers)

Axion's value proposition is memory-safe **without GC**, so the native runtime
runs under the LLVM sanitizers in CI (`scripts/sanitize.sh`, `sanitize` job), over
the `--release` LLVM IR + the C runtime:

- **Corruption (AddressSanitizer, all native fixtures):** zero use-after-free and
  zero double-free — the hard guarantee. There is also a `cargo` test
  (`native_runtime_is_leak_free_under_lsan`) that runs a subset under ASan+LSan.
- **Leaks (LeakSanitizer, proven subset):** `allocs == frees` on heap/arena/borrow
  memory (no IO).

### Deep-drop of nested objects

A flat `drop` only frees one block; an object that **owns** another (record inside
record, or sum-type payload) would leak the inner one. Deep-drop generates a
**recursive destructor** `axion_drop_<T>` per type with heap fields (Perceus
style): it frees the owned `data`-typed fields (via their destructor, or `free` if
they are leaves) and then the block itself; sum types dispatch by tag. It works for
**recursive** types (lists/trees) — the destructor recurses at runtime. It is
lowered as normal Core functions (a single new op, `LoadRaw`), so both backends get
it almost for free. Soundness rests on linearity: an embedded field is **moved**
(owned) → freed once by the parent, and the escape analysis already excludes it
from the local drop. `Term::Drop` carries the type name; the backend chooses
destructor vs. flat `free` via `needs_deep_drop`.

### Known conservative leaks (safe, outside the leak gate)

Two categories leak **by conservative choice** — they are not corruption (ASan
passes), and reclaiming them would be unsafe or would require a design decision:

1. **Runtime C-strings** (`show`, `putStrLn`): the result of `show` is a
   runtime-allocated string, but string literals are static. At the drop point
   there is no way to tell them apart, so freeing uniformly would blow up on
   literals. Reclaiming requires a `String` that marks heap vs. static.
2. **Closures returned by a function:** the return may be a fresh closure
   (`\k -> …`) **or** a borrowed closure parameter (`pick b f g = if b then f else
   g`). Treating the result as owned by the caller would double-free in the second
   case. Reclaiming requires an escape analysis over the closure (like the borrowed
   arguments one, `BorrowArgs`).

Minor (rare): a heap object bound to the result of an `if`/`case` (rather than a
direct `Make*`/call) gets a flat `free` — if nested, it leaks the inner one; and
**tuples** that own heap don't have a destructor yet (deep-drop covers `data`
types).

Already **reclaimed** (they were leaks, now closed): nested objects (deep-drop);
positional sum-type constructions (`is_heap_alloc` now includes `MakeCon`); the
closure passed to `withArena`; and the base of a by-copy `update`.
