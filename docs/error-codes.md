# `AXnnnn` error-code registry

> **Why now, in Phase 0.** §8/§17 is explicit: register **stable error codes from
> the very first error emitted** — "retrofitting a registry after hundreds of
> errors exist is painful". This file is the seed of that registry. Each code is
> stable and forever; a number is never reused.

Format: `AXnnnn`, four digits, allocated sequentially. Each entry has: the
invariant it protects, a minimal example, and (where applicable) the
*machine-applicable fix* the [LSP](lsp.md) offers (§8). Diagnostics are also emitted
as JSON and are explainable via `axion --explain AXnnnn`.

| Code | Category | Invariant violated | Status |
|--------|-----------|--------------------|--------|
| `AX0001` | Linearity | Contraction: a `%1` **or heap value** (incl. a borrowed `data`/tuple) **consumed/moved** >1 time (reading/borrowing is free) | **enforced by `axionc`** (Phase 1/2) |
| `AX0002` | Linearity | *Must-use*: a `%1` **without `Drop`** dropped without consumption (droppable types ⇒ Auto-Drop, not an error) | **enforced by `axionc`** (Phase 1/2) |
| `AX0003` | Regions | Escape: a sub-arena value escapes its scope (missing `promote`) | **enforced by `axionc`** (Phase 2) |
| `AX0004` | Linearity | Use-after-move: reading/consuming a `%1` after ownership was moved | **enforced by `axionc`** (Phase 2) |
| `AX0005` | Regions | Use-after-release: value allocated after `arena_mark` used after `arena_release` | **enforced by `axionc`** (Phase 2) |
| `AX0006` | Linearity | Write through a `%0.5` half (shared read) | **enforced by `axionc`** (Phase 2) |
| `AX0007` | Linearity | A borrowed resource parameter (a `Handle`/`Sock`/endpoint whose type has no `%1`) is consumed — the caller would consume it again | **enforced by `axionc`** |
| `AX0100` | Syntax | Syntax error / unexpected character | **enforced by `axionc`** (Phase 1) |
| `AX0101` | Names | Name not found (out of scope) | **enforced by `axionc`** (Phase 1) |
| `AX0200` | Types | Type mismatch (unification failed) | **enforced by `axionc`** (Phase 1) |
| `AX0201` | Types | Infinite type (occurs-check failed) | **enforced by `axionc`** (Phase 1) |
| `AX0202` | Types | Non-exhaustive patterns: a `case` does not cover every constructor of the scrutinee's type (or lacks a wildcard for `Int`/`Float`/`String`) | **enforced by `axionc`** |
| `AX0203` | Types | Redundant pattern: an arm after a catch-all is unreachable (*warning*) | **enforced by `axionc`** |
| `AX0300` | Sessions | Channel operation does not follow the endpoint's session type (`send`/`recv`/`close` in the wrong state) | **enforced by `axionc`** (Phase 3) |
| `AX0301` | Sessions | Incomplete session protocol: an endpoint is not carried to `close` | **enforced by `axionc`** (Phase 3) |
| `AX0302` | Sessions | Endpoint escape: an endpoint created in a `bound` is returned from the nursery (breaks the acyclic topology → deadlock risk) | **enforced by `axionc`** (Phase 3) |
| `AX0303` | Sessions | External choice (`Offer`/`&`) without the `Closed` branch: cancellation of a panicking peer would go unhandled (T5, §7) | **enforced by `axionc`** (Phase 3) |
| `AX0304` | Sessions | Non-exhaustive `case offer c`: a branch the external choice offers has no arm | **enforced by `axionc`** (Phase 3) |
| `AX0305` | Sessions | `spawn` closure captures an endpoint from outside: would break the nursery's tree topology (§9) | **enforced by `axionc`** (Phase 3) |
| `AX0400`–`AX0405` | Typeclasses | Class/instance coherence and use-site constraints (see the `AX04xx` band below) | **enforced by `axionc`** |
| `AX0500` | Levels | A declaration's *written* level (its own multiplicities/level-defining types/builtins) exceeds the module's `{-# LEVEL Ln #-}` ceiling (§8) | **enforced by `axionc`** |
| `AX0600` | Refinements | A call's refined argument (or a function's refined result) is not proven from what is known there | **enforced by `axionc`** |
| `AX0601` | Refinements | An ill-formed refinement: not an `Int`, an unknown name, `len` of a non-array, or outside the predicate language | **enforced by `axionc`** |
| `AX0602` | Refinements | A function with refined parameters used without the arguments its refinements mention (as a value, partially applied) | **enforced by `axionc`** |
| `AX0603` | Contracts | A malformed `{-# CONTRACT … #-}`: no `requires`/`ensures`, a predicate that does not parse, a function that is not top-level or has no signature, a second contract for one function (see [`contracts.md`](contracts.md)) | **enforced by `axionc`** |
| `AX0700` | Totality | A function declared `{-# TOTAL f #-}` may not terminate: some cycle of recursive calls makes nothing smaller (see [`totality.md`](totality.md)) | **enforced by `axionc`** |
| `AX0701` | Totality | A function declared total may fail at run time: incomplete patterns or guards, an array access/lane not proven in range, a divisor that may be zero, `exitWith`, an FFI call | **enforced by `axionc`** |
| `AX0702` | Totality | A function declared total calls one that is not total | **enforced by `axionc`** |
| `AX0703` | Totality | A name in a `TOTAL` pragma is not a top-level function of the module | **enforced by `axionc`** |
| `AX0800` | Parallel loops | A `parFor` kernel has an effect (I/O, exit, a channel/session/task operation, a `Buffer` or arena written in place), in its body or in a function it calls by name (see [`parallel.md`](parallel.md)) | **enforced by `axionc`** |
| `AX0801` | Parallel loops | `parFor` used without both of its arguments (as a value, or partially applied): its kernel cannot be checked | **enforced by `axionc`** |
| `AX0802` | GPU kernels | A `gpuFor` kernel uses something the GPU cannot run: a String, a list, tuple, record or other `data` value, a function value, or a built-in other than arithmetic and array reads, in its body or in a function it calls (see [`gpu.md`](gpu.md)); natively also after overloading and specialization | **enforced by `axionc`** |
| `AX0915` | Native build | A SIMD vector (`F64x4`, …) used where natively only a 64-bit slot fits: a tuple/record/constructor field, a closure capture, an argument or result of a function value, the result of `main` (see [`simd.md`](simd.md)). The interpreter runs the program | **enforced by `axionc`** (native builds) |

The ownership errors (`AX0001`, `AX0002`, `AX0004`, `AX0007`, and the native-build `AX0910`,
`AX0911`, `AX0912`, `AX0914`) print the rule of [`spec.md`](spec.md) they enforce.

Next free per band — language: `AX0008`; front-end: `AX0102`; types: `AX0204`;
channels/sessions: `AX0306`; typeclasses: `AX0406`; levels: `AX0501`; refinements and contracts: `AX0604`; totality: `AX0704`; parallel loops and GPU kernels: `AX0803`.

**`AX03xx` channels and session types (Phase 3).** The §17 band for the session
calculus (see [`docs/phase-3-calculus.md`](phase-3-calculus.md)). Enforced:
`AX0300` (fidelity — `send`/`recv`/`close`/`select` follow the session type,
including the chosen label belonging to the `Select`), `AX0301` (completeness — the
protocol reaches `close`), `AX0302` (nursery confinement — endpoints don't escape
the `bound`; structural deadlock-freedom, §9, analogous to arena escape `AX0003`
but without `promote`), `AX0303` (cancellation exhaustiveness — every external
choice `Offer`/`&` includes the `Closed` branch, T5/§7). The endpoint's linear
`%1` ownership is covered by `AX00xx` (must-use/use-after-move), `AX0304` (the
`case offer` handles all branches, incl. `Closed`) and `AX0305` (`spawn` only
creates parent↔child edges — the closure captures no endpoints → tree topology).
To implement: delegation (passing endpoints over channels between siblings, with
acyclic pipelines) and the surface→ASC differential.

> **Band note.** `AX0001`–`AX0099` for *language semantics* invariants (linearity,
> regions, sessions); `AX0100`–`AX0199` for *front-end* (syntax, name resolution);
> `AX0200`+ for *types* (HM inference); `AX0400`+ for *typeclasses*; `AX0500`+ for
> *levels* (§8 progressive disclosure). Codes are stable: a number never changes
> meaning nor is reused.

---

## `AX0001` — contraction of a linear resource (consumed >1 time)

Rule: [R5](spec.md#r5).

**Rule (§2), with fine liveness.** *Reading* (borrowing) a `%1` is free and
unlimited — Borrow Elision. *Consuming* (moving ownership: argument of a `%1`
parameter, `%1` field, or **embedding into a constructor/tuple/record**, or return
value) may happen only **once**; twice is contraction. This holds for any HEAP
value — a `data`/tuple that is deep-dropped — even a *borrowed* (non-`%1`)
parameter: duplicating it by ownership aliases it, and the deep-drop would then
free the shared payload twice (a double-free). Sharing by ownership requires
`split` into two `%0.5` halves.

```axion
process :: Buffer U8 %1 -> (Buffer U8 %1, Buffer U8 %1)
process buf = (encrypt buf, encrypt buf)
--                    ^^^            ^^^  'buf' CONSUMED twice -> AX0001
-- (but  checksum buf + checksum buf  would be OK: two READS/borrows)

mk :: List Box -> Two          -- 'xs' is BORROWED (no %1) but still a heap value
mk xs = Two xs xs              -- moved into BOTH owned fields -> AX0001
--          ^^ ^^              (would double-free the shared list natively)
```

**Bench (Phase 0).** `prototype/test/negative/UseTwice.hs` fails to compile; GHC
manifests it as a *multiplicity* error (`LinearTypes` has no Borrow Elision, so it
treats every read as a consumption).

**`axionc` (Phase 1/2).** Enforced by the fine linearity analysis
(`axionc/src/check.rs`): it classifies each occurrence of the `%1` as a borrow or
a consumption by its position; **consumptions > 1** ⇒ `AX0001`. `if`/`case`
branches count as alternative paths (maximum, not sum).
Fixture: `axionc/tests/fixtures/use_after_consume.axi`.

```
error[AX0001]: linear resource 'x' consumed 2 times (contraction forbidden)
  --> tests/fixtures/use_after_consume.axi:5:10
  |
5 | useTwice x = (x, x)
  |          ^ 'x' is %1: consumable only once
```

---

## `AX0002` — must-use resource dropped without consumption

Rule: [R3](spec.md#r3).

**Rule (§2).** Weakening (dropping) is allowed only for types with a `Drop`
instance. Types without `Drop` — session endpoints (`Ep`), `Token`, transaction
handles — are *must-use*: forgetting them is an error (Session Fidelity in §9
depends on this). Example and diagnostic shape in Listing 2.4.

**`axionc` (Phase 2, Auto-Drop).** The linearity analysis (`axionc/src/check.rs`)
classifies the type of the `%1` resource: if it is **droppable** (the default),
dropping it without consumption is **not an error** — Auto-Drop inserts `free` at
the death point (visible in `axionc --emit drops`). Only a **must-use** type
dropped emits `AX0002`. Must-use = head in `MUST_USE_PRIMS` (`Ep`, `Token`, …)
**or** a `data` that (recursively) contains a must-use field — `Drop` propagates
structurally (fixpoint). It applies to **parameters and `let` values**: a
`let v = <consumes a linear resource>` of must-use type, dropped, is `AX0002`.

```
error[AX0002]: must-use resource 'x' dropped without being consumed
  --> drop_linear.axi:4:8
  |
4 | dropIt x = 0
  |        ^ 'x' : Token %1 (no Drop)
```

## `AX0003` — sub-arena escape

**Rule (§3).** A value allocated in a sub-arena cannot escape its scope; the
escape must be a *compile* error (use `promote` to move it to the parent arena
before the reset). Example in Listing 3.5.

**`axionc` (Phase 2).** A region provenance trace (`axionc/src/check.rs`) follows
the values bound to the sub-arena of a `withSubArena parent (\sub -> …)`:
`allocateCell sub …` binds the value to the sub-arena; `promote parent v` rebinds
it to the parent arena (cuts the provenance). The escape is detected either **by
return** (the return value still bound to the sub-arena) or **by closure capture**
(a returned lambda capturing a sub-arena value, §3C) → `AX0003`, with the escape
span and the allocation span.

```
error[AX0003]: a value escapes its sub-arena
  --> arena_escape.axi:4:78
  |
4 | escapes parent = withSubArena parent (\sub -> let node = allocateCell sub in node)
  |                                                          ^^^^^^^^^^^^^^^^ lives in sub-arena 'sub'
  |                                        (…)                                     ^^^^ returned from here
```

Fixtures: `arena_escape.axi` (escapes → `AX0003`), `arena_promote_ok.axi`
(`promote` → accepted).

---

## `AX0004` — use-after-move

Rule: [R6](spec.md#r6).

**Rule (§2), order-sensitive.** Once ownership of a `%1` is **moved** (consumed —
passed to a `%1` parameter, placed in a `%1` field, or returned), it cannot be
read or consumed again: ownership has left the scope. Distinct from `AX0001`
(contraction = move twice) and from repeated reading (borrows, which are free).

**`axionc` (Phase 2).** A traversal in evaluation order (left→right, branches as
paths) marks when `x` is moved; any later occurrence is `AX0004`, with the use
span and the move span.

```
error[AX0004]: use of 'x' after ownership was moved
  --> use_after_move.axi:7:18
  |
7 | bad x = sink x + x
  |                  ^ 'x' used here…
  |
7 | bad x = sink x + x
  |              ^ …but ownership had already been moved here
```

`x + sink x` (reading **before** consuming) is accepted; `sink x + x` (reading
**after**) is `AX0004`. Fixture: `axionc/tests/fixtures/use_after_move.axi`.

---

## `AX0005` — use-after-release of an arena mark

**Rule (§3, Listing 3.6).** `mark = arena_mark arena` saves the top of the
bump-pointer; `arena_release mark` rewinds it, reclaiming **everything allocated
after the mark**. Hence a value `allocateCell arena` allocated after the mark
cannot be used **after** the `arena_release` — its memory is already reclaimed.
Intra-scope reclamation, without a sub-arena.

**`axionc` (Phase 2).** An ordered analysis over the `let` spine
(`axionc/src/check.rs`) follows the open marks, the values allocated under each
mark, and the `arena_release`; any use of a value whose mark has already been
released is `AX0005`, with the spans of the use, the release, and the allocation.

```
error[AX0005]: 'tmp' used after 'arena_release' (memory already reclaimed)
  --> arena_mark_release.axi:8:3
  |
8 |   tmp
  |   ^^^ 'tmp' used here…
  |
7 |   let done = arena_release mark in
  |              ^^^^^^^^^^^^^^^^^^ …but arena_release reclaimed the memory here
```

Fixtures: `arena_mark_release.axi` (→ `AX0005`), `arena_mark_ok.axi` (use before
the release → accepted).

---

## `AX0006` — write through a `%0.5` half

**Rule (§2, Listing 2.3).** `split` divides a `%1` into two **shared-read** `%0.5`
halves (Boyland style); `join a b` recombines them into `%1`, recovering write
access. A `%0.5` half can be **read** (borrowed) freely, but **never written** —
using it in a write position is `AX0006`.

**`axionc` (Phase 2).** On encountering `case (split …) of (a, b) -> arm`, the
analysis (`axionc/src/check.rs`) marks `a`/`b` as `%0.5` halves and rejects, in
the arm, using them in a **write position**: argument of a function's `%1`
parameter, base of a record update, or `%1` field.

```
error[AX0006]: write through the %0.5 half 'a'
  --> frac_write.axi:10:22
   |
10 |   (a, b) -> writeCfg a
   |                      ^ 'a' is %0.5 (shared read): passed to a %1 parameter (write)
```

Fixtures: `frac_write.axi` (write → `AX0006`), `frac_join.axi` (reads + `join` →
accepted, and runs).

---

## `AX0007` — a borrowed resource is consumed

Rule: [R7](spec.md#r7).

A parameter whose type has no `%1` is **borrowed**: the caller keeps ownership. For a resource
(a `Handle`, `Sock`, `Listener` or session endpoint, which has no destructor) the caller must
consume it itself, so consuming it in the callee too — passing it to an `Own`/`%1` position, or
storing it — would consume it twice: a double close.

```
error[AX0007]: borrowed resource 'h' is consumed in 'sneaky'
 --> dbl.axi:7:8
  |
7 | sneaky h = closeD h
  |        ^ 'h' is borrowed: its type has no `%1`
  |
7 | sneaky h = closeD h
  |                   ^ given to `closeD` here
```

Fix: mark the parameter `%1` (`sneaky :: Handle Dev %1 -> Int`) to take ownership — the caller
then gives it up — or only borrow it (`Borrow` arguments). The same rule covers a lambda lent a
handle by a bracket function (`withDev n (\h -> …)`): it may read the handle, not close it.
Tests: `borrowed_resource_parameter_cannot_be_consumed`, `bracket_closes_on_every_outcome`.

---

## `AX0100` — syntax error

Emitted by the lexer (unexpected character) or the parser (unrecognized
construct) of `axionc`. No recovery in Phase 1: the first error stops the
analysis. `axionc --explain AX0100`.

## `AX0101` — name not found

An identifier that is not a parameter, a local (`where`/`let`), a top-level
function, nor a builtin. Emitted by name resolution in `axionc/src/check.rs`.
When a close match is in scope (edit distance ≤ 2), it carries a **machine-applicable
fix** — `did you mean \`x\`?` in text, and a `fix` (span + replacement) in `--emit
json` that an editor can auto-apply (§8).

---

## `AX0200` — type mismatch

Hindley-Milner inference (`axionc/src/infer.rs`) could not unify two types.
Example: `bad :: Int` with body `putStrLn "hi"` (which is `IO ()`).

```
error[AX0200]: type mismatch: IO () vs Int
```

## `AX0201` — infinite type (occurs-check)

Unification would require a recursive type (a variable occurring inside the type
it would be bound to), which HM inference rejects. Emitted by `infer.rs`.

---

## `AX04xx` — typeclasses (class and instance coherence)

The `AX04xx` band covers the static coherence of typeclasses, emitted by
`check_instances` in `axionc/src/check.rs`:

- **`AX0400`** — `instance C T` of a class `C` that was not declared.
- **`AX0401`** — incomplete instance: a class method is not implemented.
- **`AX0402`** — the instance implements a method the class does not declare.
- **`AX0403`** — duplicate instance: two `instance C T` for the same (class, type)
  pair, which would make method resolution ambiguous.
- **`AX0404`** — method over a concrete type without an instance: `eq` over
  `String` without `instance Eq String`. Checked at the use site, with type
  information from inference.
- **`AX0405`** — method over a polymorphic type without a declared constraint: a
  function applying a method to a generic `a` must declare `C a =>` in its
  signature.

Method dispatch itself is dynamic in the interpreter; on the native path,
monomorphization specializes constrained functions per type and resolves methods
to the concrete instance impls — zero-cost, à la Rust (measured; see the
`dispatch` benchmark).

---

## `AX0500` — declaration exceeds the module's LEVEL ceiling

**Rule (§8, progressive disclosure).** The L0–L3 scale grades how much of the
substructural machinery a declaration exposes — **L0** plain strict-Haskell (no
linearity/regions *written*; they may be inferred but stay invisible), **L1**
linear resources (`%1`/`%0.5`) and arenas, **L2** channels and session types
(`bound`/`spawn`/…), **L3** the `Trit`/`TritVec` type and coupling (`~`/`Maybe~`).

A module caps itself with a `{-# LEVEL Ln #-}` pragma on the first line. The
ceiling is a **mechanical firewall** (à la `#![forbid(unsafe_code)]`): each
declaration whose *written* level exceeds it is rejected. A declaration's level is
the max over what it **writes in its own body and signature** — its parameter
multiplicities, the level-defining type heads in its signature, and the
level-defining builtins it names.

Crucially, the ceiling governs **what a declaration writes, not what it calls**.
Calling a user (or imported) function is an ordinary reference, never a
level-defining construct, so an `{-# LEVEL L0 #-}` module may freely depend on an
L3 library — it just may not *write* L1+ constructs itself. The ceiling only ever
**tightens**.

```axion
{-# LEVEL L0 #-}
f :: Buffer U8 %1 -> Buffer U8 %1   -- writes %1 + Buffer ⇒ L1
f b = b                             -- AX0500: L1 under an L0 ceiling
```

Fix: raise the ceiling to `{-# LEVEL L1 #-}` (or higher), or remove the
higher-level feature. Malformed pragmas (`{-# LEVEL wat #-}`) are reported as an
`AX0500` *warning* and ignored (no ceiling applied).

> Scope: the module pragma is enforced today. The manifest `max-level` cap (§8)
> awaits the `axion` driver/`axion.toml` and is deferred.

## `AX06xx` — integer refinements

See [`refinements.md`](refinements.md). A top-level signature may refine an `Int` parameter or
result (`{i:Int | 0 <= i && i < len a}`); every call proves it from the facts known where it is
made.

- **`AX0600`** — the refinement is not proven for this argument (or this return). The help line
  lists the facts known there. Add a condition on the path (`if i < lenArray a then …`), refine
  the caller's own parameters, or check the value first.

  ```haskell
  get :: a:Array Int -> {i:Int | 0 <= i && i < len a} -> Int
  bad a k = get a k            -- AX0600: nothing is known about k
  ```

- **`AX0601`** — the refinement is outside the language: a non-`Int` refined, a name that is not
  a parameter of the signature, `len` of something that is not an array parameter, or an
  operator the predicate language lacks.
- **`AX0602`** — a function with refined parameters is named without the arguments its
  refinements mention (`map idx xs`): nothing can be proven there.
