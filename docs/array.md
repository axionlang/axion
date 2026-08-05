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

## Phase 2c: Deep-drop for parametric elements

When the element type is a concrete heap type (`List P`, `Maybe P`), the
compiler threads the element type through inference → lowering → destructor
generation:

```haskell
-- 'elem_ty' resolved to 'List$P' at the call site:
a <- newArray 100 (Nil :: List P)
-- Generates: axion_drop_Array$List$P
-- Which loops i = n-1..0: loads elem[i], calls axion_drop_List$P, frees shell
```

No user annotation needed — the type inference records the element type
at each `newArray` call site, and the lowering pass populates
`Op::ArrayNew.elem_ty` from `analysis.array_tys`.

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
| `newArray`    | `Int -> Int -> Array a`                | Allocate n elements, init to val |
| `getArray`    | `Array a -> Int -> Int`                | Read element at index            |
| `setArray`    | `Array a %1 -> Int -> Int -> Array a`  | Write element in-place (linear)  |
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
  in the state machine — there is no `while` or `for`. Large arrays must be
  filled and read element-by-element via recursive helper functions (which
  require monomorphic type signatures for native compilation).
- **No bounds checking.** `getArray` returns 0 for out-of-bounds; `setArray`
  is a no-op for OOB.
- **No bulk operations.** No `fill`, `copy`, or `iota` — each element must be
  individually set/read.
