# Design plan — unbounded recursion without stack overflow (grow-on-demand)

**Status:** proposal. **Goal:** make it a *language-level guarantee* that no Axion
program can crash with a stack overflow. Deep recursion grows on the **heap**
(bounded by RAM), and the only failure at exhaustion is the **clean OOM abort**
(`axion: out of memory …`) already implemented — never a `SIGSEGV`/`stack
overflow`.

This is "approach (2)" — the real fix, beyond the large-stack ceiling of approach
(1) (`EVAL_STACK_SIZE`, 2 GiB), which raises the limit but keeps a fixed ceiling
and an ugly failure mode (a page fault at RAM exhaustion, not a clean abort).

## 1. Success criteria (and non-goals)

**Must hold when done:**
- No input causes a `stack overflow` / `SIGSEGV` from recursion depth, on **any**
  executor (`--dev`, `--release`, interp).
- Depth is bounded by heap (RAM), not by a fixed stack. At exhaustion → the clean
  OOM abort.
- **Semantics unchanged** — same results as today (verified by the GHC differential
  oracle) and **memory-safe** (verified by ASan/LSan) — the drop/linearity timing
  must be identical.
- **Tail recursion is unaffected** (already a loop via TCO) and **non-recursive code
  is unaffected** (stays on the native stack, full speed).

**Non-goals:**
- Running unbounded recursion in *finite* memory — impossible; genuinely-deep
  recursion still exhausts RAM, but *cleanly*.
- Beating C on the transformed (non-tail-recursive) hot path in Phase 1 (see §6 for
  the fast-path that reclaims it).

## 2. Why the simple options fall short

- **Even bigger fixed stack** (extend approach (1) to, say, 1 TiB via lazy `mmap`):
  raises the ceiling to RAM, but a stack page fault at RAM exhaustion is a
  `SIGSEGV`/OOM-kill, **not** a clean abort. It is approach (1) with a bigger
  number, not a guarantee.
- **Segmented native stacks** (LLVM `-fsplit-stack` + a `__morestack` runtime, à la
  old Rust / Go's first design): works only for `--release` (LLVM), **not**
  Cranelift, so it splits the two backends; and it has the well-known **hot-split**
  performance cliff (a call at a segment boundary inside a loop repeatedly
  grows/shrinks). Rust removed it for these reasons.
- **`ucontext`/stack-switch**: can start a computation on a heap stack, but cannot
  *continue* a computation mid-frame on a **bigger** stack without **copying** the
  live frames — and copying needs to relocate every pointer into the stack, which
  needs precise stack maps (a moving-GC-grade facility Axion does not have).

The one approach that gives the clean, bounded, backend-uniform guarantee **without
stack maps** is a **heap-allocated continuation stack** — and Axion already has a
proven instance of it.

## 3. The approach: a heap continuation stack (defunctionalized abstract machine)

**Precedent in the codebase.** The native **session** runtime (§11) already compiles
each session task to a **defunctionalized state machine**: a `step(sched, state)`
function whose locals live in a **heap** task-state block (`Op::StoreRaw`/`LoadRaw`
save/restore across suspension points), driven by a scheduler loop — *not* the
native call stack. Deep session recursion (`server` loops) is already
stack-independent and ASan/LSan-clean. Generalizing this from "suspend at `recv`"
to "suspend at a self/mutual recursive call" is the whole idea.

**The model.** A recursive function is compiled to an explicit **abstract machine**
(a CEK-style machine):
- a **heap stack of frames** — each frame is a defunctionalized *continuation*
  ("what to do with the result of the call I am about to make"), carrying the saved
  live locals;
- a **driver loop** with two modes: *eval* (evaluate a call) and *return* (hand a
  value to the top frame);
- the stack grows via Axion's **checked allocator** (`axion_xmalloc`/`realloc`), so
  exhaustion is the **clean OOM abort**, and depth is bounded by RAM.

**Worked example** — naive `fib` (non-tail; the only benchmark that needs this):

```
fib n = if n < 2 then n else fib (n-1) + fib (n-2)
```

Two call sites, so two frame shapes:
- `NeedSecond(n)` — pushed before `fib (n-1)`; on return of `v1`, evaluate
  `fib (n-2)` after pushing `Add(v1)`;
- `Add(v1)` — on return of `v2`, produce `v1 + v2` and return to the frame below.

Driver:
```
push Halt; goto eval(n)
eval(n):    if n < 2 then goto ret(n)
            else push NeedSecond(n); goto eval(n-1)
ret(v):     case pop() of
              Halt         -> return v
              NeedSecond n -> push Add(v); goto eval(n-2)
              Add v1       -> goto ret(v1 + v)
```
No native recursion — a loop over a heap frame stack. Depth is limited only by how
many `Frame`s the heap holds.

## 4. Detailed design

### 4a. Scope — which functions are transformed
- Compute the **call graph** and its **strongly-connected components** (SCCs).
  A function is "recursive" iff it is in a non-trivial SCC or calls itself.
- **Tail** self/mutual calls are already loops (TCO, `core::has_tail_self_call`) —
  leave them.
- Only **non-tail recursive** functions (single- or mutually-recursive) get the
  machine transform. Everything else stays native (full speed, native stack) — so
  the cost is confined to exactly the code that can otherwise overflow.

### 4b. The transformation (a Core→Core pass)
Do it on the **Core IR** (ANF already), so **both backends reuse existing codegen**
— the machine is just ordinary `Term`/`Rhs`/`Op` (a loop, a `case` over a frame
tag, and heap load/store). No new Cranelift/LLVM features.
1. **ANF/CPS-normalize** each recursive function so every recursive call is a named
   `let` whose continuation is explicit (Core is already ANF — the continuation is
   "the rest of the `Term`").
2. **Defunctionalize** the continuations at recursive-call sites into a **frame sum
   type** `Frame = Halt | <one constructor per recursive call site, carrying the
   live locals>` (the live set is exactly what `check.rs` already computes for
   Auto-Drop and what `sess_layout` computes for session suspension).
3. Emit the **driver**: an `eval`/`ret` loop over an explicit frame stack, exactly
   like the session `step` machine but with a self-managed stack instead of the
   scheduler.
4. The frame stack is a growable heap buffer (`[len][cap][frames…]`), pushed/popped
   by helpers `axion_frames_push`/`_pop` (new §-runtime, mirroring `axion_sess_*`).

### 4c. Drop / linearity — the subtle, safety-critical part
Auto-Drop (§2) frees a linear resource at its **death point**. In the machine, a
resource lives inside a **frame** until the frame is popped. So:
- Each frame carries its owned linear resources (already known: the live set).
- **Popping a frame runs that frame's drops** at the same logical point the native
  version would — reuse the existing per-function drop analysis, applied per frame.
- This is precisely what the session runtime already does (frame-scoped heap
  lifetimes, ASan/LSan-clean). The risk is *implementation* correctness (frame
  layout + drop timing), **not** a new class of unsafety — no raw pointers reach the
  user, and the machine is under runtime control.

### 4d. The interpreter
The interp is a Rust tree-walker (fat frames). Two options: (i) apply the same
abstract-machine idea in the evaluator (a `Vec<Frame>` continuation stack instead of
Rust recursion — an explicit CEK loop), or (ii) accept the interp as the shallow-run
reference tool and rely on approach (1)'s large stack there. **Recommend (ii) first**
(the interp is not the production path; the guarantee that matters is native), and
(i) as a later hardening.

## 5. Backends — no new codegen
Because the transform outputs Core IR, `codegen.rs` (Cranelift) and `llvm.rs` (LLVM)
compile it **unchanged**. The only additions are runtime helpers
(`axion_frames_push/pop/free`), added exactly like the existing `axion_sess_*`
family (Rust extern for `--dev`, C for `--release`, declared in `RT_DECLS`). This
keeps the two backends in lockstep and the change concentrated in `core.rs` + the
runtime — the same shape as every feature we have shipped.

## 6. Phase 2 — reclaim the fast path (grow-on-demand)
Phase 1 makes **all** non-tail recursion use the heap machine → `fib` and other
non-tail recursion pay a heap push/pop per call (~2–4×; measured against `fib` in
`scripts/bench.sh`). To restore the "zero cost in the common case" property:
- Compile the recursive function in **both** forms (native + machine), OR add a
  **depth budget**: recurse **natively** (fast) up to `N` frames; when a prologue
  check sees the budget exhausted, **switch to the heap machine** for the remaining
  depth. Shallow recursion (e.g. `fib 40`, depth 40) never leaves the native stack
  → **benchmarks unchanged**; only genuinely deep recursion pays — and only the
  part beyond `N`.
- The switch needs the machine form to be **re-entrant at an arbitrary depth**
  (start with a seed frame), which the design already supports. The prologue check
  is a single compare against a thread-local limit (cheap).
- Phase 2 is the harder, optional half. Phase 1 already delivers the **guarantee**;
  Phase 2 delivers the guarantee **at no common-case cost**.

## 7. Verification
- **Differential oracle** (`scripts/differential.sh`, GHC): the transform must be
  semantics-preserving — every fixture must still match GHC.
- **ASan/LSan** (`scripts/sanitize.sh`): the frame-scoped drops must be leak- and
  corruption-free — this is the gate that guards §4c.
- **Stress**: a `recursion_depth` test at depth 10^8 must return the right result
  with **zero** stack growth (RSS bounded by the heap frames), and a
  depth-to-exhaustion test must end in the **clean OOM abort**, never a segfault.
- **Bench**: `scripts/bench.sh` — Phase 1 shows the `fib` cost; Phase 2 shows it
  restored.

## 8. Cost, risk, phasing
- **Effort:** large — a new Core→Core pass (SCC analysis + CPS/defunctionalization +
  per-frame drop lowering) plus a small runtime. Weeks-scale, the biggest single
  change since native sessions. But *concentrated* (core.rs + runtime; backends
  untouched) and built on a **proven** mechanism (sessions).
- **Risk:** correctness of the frame/drop lowering (mitigated by the oracle +
  sanitizer gates that already exist); **not** a new unsafety surface.
- **Phasing:**
  1. SCC/non-tail-recursion detection + the frame runtime helpers.
  2. Single-recursion transform (self-recursive `fib`-shaped) end-to-end, oracle +
     sanitizer green, on both backends.
  3. Mutual recursion (SCCs > 1).
  4. (Optional) Phase 2 fast-path (depth budget) to erase the common-case cost.
  5. (Optional) interp CEK loop.

## 8b. Findings from prototyping (before building the pass)

A hand-written abstract machine for `sumR` (`data Frame = FAdd Int; evalS`/`retS`
over a frame stack) was used to validate the mechanism *before* writing the
transform. Results:

- **The core insight holds.** With a `List Frame` stack and the existing self-TCO,
  `evalS`/`retS` each become loops; the native call stack stays **O(1)** while the
  depth lives in the heap list. `sumM 10000000` returns the right result on
  `--dev` and `--release` with **no** stack growth. → defunctionalization + TCO =
  heap continuation stack, confirmed.
- **The frame stack must NOT be a linear `List` — confirming §4b.** A non-linear
  `List Frame` **leaks** (200k allocs, 0 frees — a borrowed parameter is never
  freed). Making it `List Frame %1` (linear, so it is owned and freed as consumed)
  instead **double-frees**: matching `Cons f rest` deep-drops the `Cons`, which
  recursively frees `rest` — but `rest` is transferred to the recursive call. So the
  stack must be the **flat, runtime-managed buffer** (`axion_frames_push/pop`, §4b),
  which frees each frame shell explicitly on pop — never a recursive linear ADT.
- **Latent Auto-Drop bug discovered (independent of this plan).** The double-free
  above is *general*: any incrementally-consumed **linear recursive ADT**
  (`data L = LN | LC Int L`, `sumL :: L %1 -> Int`, `case xs of LC y ys -> … sumL
  ys`) double-frees natively — the interpreter gives the right answer (it is memory
  agnostic), but the native deep-drop of the matched `LC` frees the transferred tail
  `ys` too. The existing linear examples are flat `Buffer`s, so this pattern was
  never exercised. The fix is in the Auto-Drop analysis: when a matched
  constructor's heap field is **bound and used** (ownership transferred), the parent
  must be freed **shallowly** (shell only), not deep-dropped. This should be fixed
  independently — it is a real (if untested) memory-safety gap — and the frame-stack
  design above sidesteps it regardless.

## 9. Bottom line
A genuine, backend-uniform guarantee — *"an Axion program never stack-overflows"* —
is achievable and safe, and Axion already ships the hard part (defunctionalized
heap continuations, in the session runtime). It is a real project, not a flag flip:
Phase 1 delivers the guarantee with a cost confined to non-tail recursion; Phase 2
removes even that cost for shallow recursion. The alternatives (giant stack,
segmented native stacks, `ucontext`) each fail one of {clean failure, backend
uniformity, no-stack-maps} — the heap continuation stack is the one that meets all
three.
