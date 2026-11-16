# Array — packed, mutable arrays with linear ownership (§A)

Axion's `Array a` provides O(1) random-access mutable storage. Unlike `List a`
(linked Cons cells, 24 bytes/element), `Array a` uses contiguous memory (8
bytes/element + 8-byte length header), matching C arrays in layout and
cache behaviour.

## Phase 2a: Auto-drop

Arrays are automatically freed at end of scope via `axion_drop_Array`:

```haskell
main :: Int
main = imperative $ do
  a <- newArray 5 0       -- allocate 5 elements, all zero
  getArray a 0             -- returns 0
-- array freed here — no manual 'free' needed
```

The destructor generation follows the same pattern as `axion_drop_List`:
- `newArray` produces an `Array` resource tracked by the Δ (linearity) checker
- At the variable's death point, `insert_drops` emits `drop x : Array`
- The backend routes to `axion_drop_Array` → `axion_array_free`

## Phase 2b: In-place mutation

`setArray` consumes the old array (linear, `Mult::One`) and returns the same
pointer — true in-place mutation with no copy:

```haskell
main :: Int
main = imperative $ do
  a <- newArray 3 0
  a <- setArray a 0 10    -- in-place: a[0] = 10
  a <- setArray a 1 20
  getArray a 0             -- returns 10
```

## Element types

Scalar elements (`Int`, `Float`, `Bool`, `Char`, a `data` type whose constructors take no
fields) are stored as raw words, exactly as before.

An array of **heap** elements (`String`, `Integer`, a `List`, a tuple, a `data` value with
fields, or any type made of those) owns its elements, with value semantics:

- `newArray n x` and `setArray a i x` store a **copy** of `x`; the caller keeps its own `x`
  and frees it as usual.
- `getArray a i` returns a **copy** of the element, owned by the caller.
- `setArray` frees the element it replaces, and dropping the array frees every element.

Natively, each operation at a concrete element type `K` calls a generated helper
(`axion_arrop_new$K`, `axion_arrop_get$K`, `axion_arrop_set$K`; Core has no loops, so `new`
fills by recursion), and the array is dropped by `axion_drop_Array$K`, which frees each
element and then the block. The helpers manage memory by hand, like the generated destructors
and copiers; their call-site ownership is fixed (`new`/`get` borrow everything, `set`
consumes the array and borrows the element), so the drop verifier checks every user
function that uses them. Fixture: `array_heap_elems.axi` (3 backends, leak-gated).

A native build still refuses an array operation (`error[AX0914]`) when its element type is not
a concrete copyable type **at the operation itself**:

- the type is only known through a generic function (`fill :: Int -> a -> Array a` called at
  `List Int`): the error points at the call that fixes the type. Give the function a concrete
  signature (`Array String` rather than `Array a`);
- the element cannot be copied: a closure, an `Array`, a `Buffer` or a handle, or a type
  holding one.

The interpreter runs any element type. Fixture: `array_heap_elem_reject.axi`.

## Imperative block

Array operations are accessed via the **imperative block** — a defunctionalized
state machine in the Core IR (`Op::ArrayNew`, `Op::RtCall`).

```haskell
main = imperative $ do
  a <- newArray 5 0
  a <- setArray a 0 10
  getArray a 0
```

**Operations:**

| Operation     | Signature                              | Purpose                          |
|---------------|----------------------------------------|----------------------------------|
| `newArray`    | `Int -> a -> Array a`                  | Allocate n elements, init to val |
| `getArray`    | `Array a -> Int -> a`                  | Read element at index            |
| `setArray`    | `Array a %1 -> Int -> a -> Array a`    | Write element in-place (linear)  |
| `lenArray`    | `Array a -> Int`                       | Number of elements               |

## Runtime representation

```
[length: i64][elem_0: i64][elem_1: i64]...[elem_N-1: i64]
```

All elements are `i64` — the uniform representation of Axion values.
For `Array (List P)`, each element is an `i64` pointer to a `List P` heap object.
For `Array Int`, each element is the raw `i64` value (no boxing).

## Native backends

The `--release` (LLVM) and `--dev` (Cranelift) backends handle `Op::ArrayNew`
by emitting a call to the runtime function `axion_array_new`. The runtime
uses `axion_xmalloc` (C) or `std::alloc::alloc` (Rust).

The interpreter does **not** support the imperative block — a pre-existing
limitation shared with `Buffer` operations.

## Limitations

- **No loop support in the imperative block.** Each operation is a fixed point
  in the state machine — there is no `while` or `for`. Large arrays are filled/read
  via **recursive helper functions** (monomorphic signatures, e.g. `fill :: Array Int
  -> Int -> Int -> Array Int` that threads the array, `sumArr :: Array Int -> …` that
  reads it): these compile and run natively, and the array is reclaimed exactly once
  (fixpoint borrow analysis + uniquify + single-var-case collapse — see
  `validation-report.md` F-3). Both the `let`-shadowing form and the `imperative do`
  form work; `bench/array_loop.axi` fills+sums 50 M elements.
- **Bounds are checked at runtime → abort.** `getArray`/`setArray` validate the index
  and **`abort()`** with `array bounds — index N out of range [0, len)` on OOB
  (`axion_rt.c`) — a clean abort, not memory corruption or a silent 0/no-op. No
  *static* bounds checking.
- **Interpreter.** Runs Array programs too (any element type), alongside `--dev`/`--release`.
- **No bulk operations.** No `fill`, `copy`, or `iota` — each element must be
  individually set/read.
- **Heap elements are copied.** Reading or storing a heap element copies it (see above):
  an array of large values pays a copy per access. Generic code over `Array a` instantiated at
  a heap type, and arrays of closures/arrays/handles, are refused natively (AX0914).
