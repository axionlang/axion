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

## Element types: scalars only in native builds (AX0914)

`newArray :: Int -> a -> Array a`, `getArray :: Array a -> Int -> a` and
`setArray :: Array a -> Int -> a -> Array a` are generic in the element type, so a program
can put any value into an array. Natively, though, an element is a raw word the array does
not own: `newArray` writes the same word into every slot, `getArray` returns it as if it were
a fresh value, and freeing the array frees only its block. With a heap element (a `List`,
`String`, `Integer`, tuple, closure, or a `data` value with fields) that leaks, or double-frees
once two reads consume the element. The drop verifier cannot see it, since it treats elements
as scalars.

So a native build rejects an array whose element type is heap (`error[AX0914]`), reporting
the `newArray`/`setArray` call, or the call to a generic function that passes its type
variable on to one of them (inference traces the variable through every instantiation). The
allowed elements are `Int`, `Float`, `Bool`, `Char`, and `data` types whose constructors take
no fields (immediate tags). The interpreter runs any element type. Fixture:
`array_heap_elem_reject.axi`.

Real heap-element arrays would need `newArray` to copy its initial value into each slot,
`getArray` to return a copy or a borrow, `setArray` to free the element it replaces, and a
per-element destructor (`axion_drop_Array$List$P`, whose generator already exists in
`core.rs` but is never triggered: `Op::ArrayNew.elem_ty` stays `None`).

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
- **Scalar elements only natively.** `Int`, `Float`, `Bool`, `Char` or a field-less `data`
  type; a heap element type is rejected with AX0914 (see above).
