# The FFI trust boundary

Axión's memory-safety guarantee (`metatheory/GUARANTEE.md`) is **machine-checked up to the FFI
boundary and does not cross it.** This document states, precisely, where that boundary is, what is
still guaranteed on the Axión side of it, and what becomes the programmer's responsibility once a
value is handed to C. It is the detailed treatment behind GUARANTEE.md §5's FFI bullet.

The short version: a `foreign` call is an **unsafe island**. The verifier, the linearity checker,
and the Lean model all stop at `Op::Ffi`. Everything *up to* the call is checked as usual;
everything the C side then does — and every raw pointer that escapes into it — is trusted.

---

## 1. Where the boundary is

A `foreign` import lowers to `Op::Ffi` (`core.rs`). At that node:

- **The drop-balance verifier** (`verify.rs`, AX0910/AX0911) treats the call's arguments per their
  declared ownership (below) and treats the **result as an opaque scalar** — an `Int`/`Ptr`/`Float`,
  never an auto-dropped owned heap value. It does not model anything the C function does.
- **The linearity checker** (`check.rs`) sees the FFI's arguments through the same ownership
  declaration; it cannot see into C.
- **The Lean faithfulness bridge** (`metatheory/model-trace.sh`) classifies any function containing
  an `Op::Ffi` as **out-of-fragment** (`model_trace.rs` returns `Err("ffi")`), so the machine-checked
  `acceptsL = verdict` agreement is simply **not asserted** across the boundary — it is not claimed
  and not relied upon.
- **`load_libs`** (`ffi.rs`) `dlopen`s whatever `.so` paths the program names. Loading and calling
  arbitrary native code is outside the TCB discussion entirely.

So the guarantee's theorem (GUARANTEE.md §1) holds for the compiled Axión code; the behavior of the
C callee, and of any pointer Axión passes it, is assumed-correct, not proven.

---

## 2. What IS still guaranteed, up to the boundary

Crossing to C does **not** weaken the Axión side. For code that only *prepares* FFI arguments and
*reads back* results, the full guarantee still applies, and several FFI-specific checks were added
so the boundary is honest rather than silently lossy:

- **Buffers are reclaimed and bounds-checked.** A `Buffer` (`newBuffer`) is a linear heap resource
  freed by `DropWay::Buf` → `axion_buf_free` at its death point (LSan-proven leak-free); every
  `peek*`/`poke*` is bounds-checked against the buffer's stored length, so **Axión-side** access
  cannot run off the end.
- **Ownership transfer is explicit and verifier-enforced.** `foreign f :: Own T -> …` marks an
  argument whose ownership passes to C: it is **consumed** (`delta.rs` moves it; `check.rs` records
  `Mult::One`), so reusing it after the call is a use-after-move (AX0910) and Axión never also frees
  it. Unmarked / `Borrow T` arguments stay owned by Axión and are freed exactly once. The default is
  borrow.
- **Handles are type-distinct.** `Ptr a` is a type-safe opaque handle: `Ptr Window ≠ Ptr Renderer ≠
  Int`, so mixing handle kinds (or an `Int`) is a compile error (AX0200), not a silent raw-integer
  confusion. It flows as a raw `i64` and is never reclaimed.
- **The float ABI is correct.** A `Float` argument/result crosses as a `double` in an FP register
  (the backends bitcast at the boundary), matching the C ABI — not the integer-register path that
  silently returned wrong values before.
- **The interpreter refuses what it cannot run faithfully.** `Foreign::interp_safe` restricts the
  interpreter to all-scalar (`Int`/`Bool`) signatures of arity ≤ 3; a float/pointer/high-arity FFI
  call is refused with an explicit *native-only* error rather than run as a diverging approximation.
  So the three backends never silently disagree on an FFI program.

---

## 3. What is NOT guaranteed, past the boundary

These are the **escape hatches**. Each is sound Axión code that the compiler accepts, but whose
*misuse* is undefined behavior the compiler cannot catch — because the unsafety lives in C, or in a
raw pointer the verifier can no longer track.

- **`bufPtr :: Buffer a -> Int`** and **`bufPtrN :: Buffer a -> Int -> Int`** return the raw data
  address of a buffer for passing to C. Two independent hazards:
  - **Size.** C reads/writes through the pointer however it likes; nothing checks the buffer is big
    enough. `bufPtrN buf minBytes` aborts if the buffer holds fewer than `minBytes` — but the floor
    is **caller-asserted** (you write `128`), so a wrong floor is still wrong. Prefer `bufPtrN` over
    `bufPtr` at every C call, stating the struct size C expects.
  - **Lifetime.** `bufPtr`/`bufPtrN` yield an opaque `Int`; the verifier **cannot tell it aliases
    the buffer**, so if the buffer has no Axión use *after* the FFI call, Auto-Drop may free it
    *before* C reads through the pointer — a use-after-free the verifier cannot see (it is across the
    boundary). **Rule: a buffer passed to C by pointer must have a use after that call** (e.g. a
    `peek` read back), which anchors the drop past the call. (This bit the imv zoom path: the rect
    buffer was freed before `SDL_RenderCopy` read it → a black frame.)
- **`intToPtr :: Int -> Ptr a`** / **`ptrToInt :: Ptr a -> Int`** / **`nullPtr :: Ptr a`** are the
  `Ptr` escape hatches. `intToPtr` fabricates a handle from an arbitrary integer; passing a bogus or
  dangling `Ptr` to C is UB. The type system guarantees only that you do not *mix kinds* — not that a
  handle is live or valid.
- **`Own T` is a caller-asserted contract.** The compiler enforces that *Axión* will not also free an
  `Own` argument; it **trusts your claim** that C takes ownership (and will free it, with the matching
  allocator). A wrong `Own`/`Borrow` annotation produces a leak (if neither side frees) or a
  double-free/bad-free (if both do, or C frees with the wrong allocator) — neither is caught.
- **Returned handles are manually managed.** A pointer C returns (an `SDL_Window*`, a `malloc`'d
  block) is an opaque scalar with **no lifecycle tracking** — unlike the linear `Sock`/`Listener`
  session types, there is no close-once enforcement. Forgetting to destroy it leaks; destroying it
  twice, or using it after destroy, is a C-side double-free / use-after-free the verifier does not
  model.
- **The C callee itself** — whatever `dlopen`/`dlsym` resolves — is entirely trusted. A bug in the
  foreign library is a bug in the program.

---

## 4. Writing FFI safely — the contract

When you cross the boundary, *you* are discharging the proof obligations the verifier normally
discharges. The checklist:

1. **Size every buffer at the call site** with `bufPtrN buf n`, where `n` is the number of bytes C
   reads or writes (the struct size). Never use bare `bufPtr` for a buffer C writes into.
2. **Keep the buffer live across the call.** Give it an Axión use (a `peek`) *after* the FFI call, so
   it is not freed while C still holds the pointer.
3. **Declare `Own` only when C truly takes ownership** and frees with a compatible allocator;
   otherwise leave the argument `Borrow` (the default) so Axión frees it once.
4. **Treat returned handles as manually managed:** pair every create with exactly one destroy on
   every path, and never use a handle after destroying it. (This is the discipline a future
   linear-handle hardening would make the compiler enforce — see below.)
5. **Run FFI programs natively.** The interpreter refuses non-scalar FFI by design; `--backend
   cranelift` / `--release` are the faithful executors.

`examples/imv.axi` is the worked example: a real SDL2 viewer that follows this contract (sized
`bufPtrN` at every call, a `peek` read-back that anchors each scratch buffer past its FFI call, and
all-`Borrow` arguments since SDL takes ownership of none of them), and whose header states plainly
that it is a *demo of reach*, not a safe-by-construction artifact. Its manually-paired
texture create/destroy is exactly the handle discipline item 4 asks for — and exactly what the
deferred linear-handle hardening would let the compiler enforce.

---

## 5. Relationship to the guarantee, and what would move the boundary

- This boundary is the FFI entry in GUARANTEE.md §5 ("escape hatches and characterized
  incompleteness"). It is an **honest limit of scope**, not a hole in the in-scope claim: the
  theorem never quantified over C behavior.
- The **trusted base** (GUARANTEE.md §4) separately includes the small, documented `unsafe` blocks in
  `axion-rt` (the runtime's own pointer/layout/FFI code), audited under ASan/LSan/TSan — distinct
  from *user* FFI, which is the subject of this document.
- **Pushing the boundary outward** (moving responsibility back to the compiler) is future work:
  - *Linear handles* — model SDL/`malloc` handles as must-use linear types like `Sock`/`Listener`,
    so leak / double-destroy / use-after-destroy of a handle become compile errors.
  - *A scoped pointer bracket* — `withBufPtr :: Buffer a -> (Int -> b) -> b` would keep a buffer live
    for the whole continuation, making the §3 lifetime hazard impossible by construction instead of
    relying on the read-back-after-call rule.
