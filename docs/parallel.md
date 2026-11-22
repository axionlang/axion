# Parallel loops

`parFor` runs a loop over an array on every core. It gives the same result as the sequential
loop, whatever the number of threads and whatever order they run in. A program that compiles
has no data races.

```haskell
parFor :: Array a -> (Int -> a -> a) -> Array a
```

`parFor a k` replaces every element `i` of `a` by `k i a[i]` and returns the array:

```haskell
-- a matrix (row-major, n × n) times a vector: one row per element of the result
matVec :: Array Float -> Array Float -> Int -> Array Float
matVec m v n = parFor (newArray n 0.0) (\r _ -> dotRow m v n r 0 0.0)

dotRow :: Array Float -> Array Float -> Int -> Int -> Int -> Float -> Float
dotRow m v n r j acc =
  if j >= n then acc else dotRow m v n r (j + 1) (acc +. getArray m (r * n + j) *. getArray v j)
```

The kernel `k` may be a lambda or a named function. It may read anything it captures (`m` and
`v` above), call any function, allocate and free, and use `parFor` itself.

## Why it cannot race

- **Each element is written once, by one thread.** The indices are cut into disjoint blocks, and
  each block goes to one thread. Element `i` is read (`a[i]`, the kernel's second argument) and
  written by the thread that owns its block, and by no other.
- **Nothing else can see the array while the loop runs.** `parFor` consumes the array like
  `setArray` does, so the caller cannot use the old one. The kernel cannot reach it either:
  the array is the loop's own input, not a capture.
- **The kernel only computes.** It must not have an effect whose order would show: I/O,
  `exitWith`, a channel, session or `spawn`, or writing in place something it captured (a
  `setArray`/`storeF64x4` on a captured array, a `Buffer` poke, an arena). The compiler refuses
  such a kernel (**AX0800**). It looks into the kernel's body and, transitively, into every
  function the kernel calls by name, and names the path to the effect:

  ```
  error[AX0800]: a `parFor` kernel must not have effects: it uses `viaLogged` → `logged` → `putStrLn`, which has effects
  ```

  The check needs to see the kernel, so `parFor` must be applied to both of its arguments where
  it is written (**AX0801** otherwise).

What the kernel reads is never written during the loop, and what it writes is never read by
another thread, so the result cannot depend on scheduling. The interpreter runs the same loop
sequentially, and every backend prints the same output.

A kernel writing a captured array in place is also caught natively by the drop verifier: the
write's result is the closure's own capture, and freeing it is a corruption finding (AX0910).
The same holds for any closure (`let f = \i -> … setArray cap …` called twice). One case is not
covered yet: a lambda given to a higher-order function that is specialized for it (`map (\i ->
… setArray cap …) xs`) becomes a function taking the capture as a parameter, and the verifier
does not see that parameter being written on every call.

The check needs to see the kernel itself. A function passed in as a value and called by the
kernel (`f` in `tabulate n f = parFor (newArray n 0) (\i _ -> f i)`) is not looked into: its
effects are the caller's responsibility. Its writes still cannot touch the array being filled.

## Elements

On the interpreter the elements can be of any type. Natively they are `Int`, `Float`, `Bool` or
`Char`: values stored directly in the array. An array of `String`s or other heap values would
need the old element freed and the new one owned per slot, which `parFor` does not do yet.

## How it runs

- The runtime (`axion_par_for` in `axion-rt`) splits the indices into blocks of at least 64
  elements, about 8 per thread, and threads take blocks from a shared counter. Uneven work (a
  kernel whose cost varies with `i`) is shared out as threads finish their blocks.
- The threads are started on first use and kept, so a `parFor` costs a wake-up, not a thread
  start. The calling thread works too.
- Small loops stay sequential. The calling thread runs the first block itself and times it. If
  the whole loop would take less than about 50 µs, it finishes alone, since waking the other
  threads would cost more.
- A `parFor` inside a kernel runs on that kernel's thread. So does a `parFor` started while
  another one is running elsewhere, for instance from a session task.
- Threads: `AXION_PAR_THREADS` (else `AXION_SESS_THREADS`, else every core).

On 8 hardware threads, a kernel of uneven integer work over 3,000,000 elements runs 4.5–5.5×
faster than on one thread (406 ms → 74–92 ms).

## Totality

`parFor` is total: a total function may use it, and its kernel is checked with the function
([totality.md](totality.md)).

Fixtures: `tests/fixtures/parfor.axi`, `parfor_reject.axi`.
