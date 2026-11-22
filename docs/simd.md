# SIMD vector types

`F64x2`, `F64x4`, `I64x2` and `I64x4` are fixed-width vectors of `Float` or `Int` lanes. They
are plain values, like `Int`: nothing is allocated, nothing is reclaimed, and they can be used
any number of times.

```haskell
-- the sum of xs[i] * ys[i] over the whole arrays, four lanes at a time (n a multiple of 4)
dotLoop :: Array Float -> Array Float -> Int -> Int -> F64x4 -> Float
dotLoop xs ys i n acc =
  if i + 4 <= n
    then dotLoop xs ys (i + 4) n (fmaF64x4 (loadF64x4 xs i) (loadF64x4 ys i) acc)
    else sumF64x4 acc
```

Under `--release`, `acc` stays in one 256-bit register for the whole loop. Each iteration does
two vector loads and one fused multiply-add.

## Operations

For each type `T` (`t` is its name in lower case, `e` its lane type: `Float` for `F64xN`, `Int`
for `I64xN`):

| | |
|---|---|
| `t :: e -> … -> T` | build from its lanes (`f64x4 1.0 2.0 3.0 4.0`) |
| `splatT :: e -> T` | every lane the same |
| `+ - *` | lane-wise; `Int` lanes wrap, like `Int` |
| `/` | lane-wise, `Float` lanes only |
| `minT`, `maxT :: T -> T -> T` | lane-wise `if a < b then a else b` (resp. `>`) |
| `fmaT :: T -> T -> T -> T` | `a * b + c` rounded once (`Float` lanes only) |
| `sqrtT :: T -> T` | `Float` lanes only |
| `laneT :: T -> Int -> e` | lane `i`; an index outside `[0, n)` aborts |
| `sumT :: T -> e` | the lanes added left to right |
| `loadT :: Array e -> Int -> T` | lanes `i … i+n-1` of the array |
| `storeT :: Array e -> Int -> T -> Array e` | writes them in place and returns the array, like `setArray` |

A load or store checks the whole range once. If any lane index falls outside the array, it
aborts with the same message as `getArray`, naming the first index that is out of range. It
compiles to that one check followed by unchecked vector accesses.

Every backend computes the same bits. Arithmetic is exact IEEE (no reassociation, no fast-math),
`fma` rounds once everywhere, and `sum` always adds in the same order.

## Where a vector can go

On the interpreter a vector can go anywhere a value can. Natively it lives in vector registers,
not in the 64-bit slot every other value uses. So it can be a variable, a function parameter or
result, loop state, or the result of an `if`/`case`, but it cannot be:

- a field of a tuple, record or constructor (so not in a list either);
- captured by a closure, or passed to or returned from a function value;
- passed to a function that is also used at another type in a way that is not specialized;
- the result of `main`.

Any of these is **AX0915** on a native build, pointing at the use. Keep the lanes in an
`Array Float` (`storeF64x4`) or as `Float`s instead.

## How it is compiled

- **Core.** Vector operations are `Op::Vec` (`axionc/src/simd.rs`). Before either backend
  runs, `simd::analyze` works out which variables, parameters and results hold vectors. It
  joins the values that flow into each other (copies, call arguments and results, branch joins)
  and rejects a vector that meets a 64-bit-slot use (AX0915). The ownership machinery and the
  drop verifier see vectors as the plain values they are.
- **`--release` (LLVM).** Vectors are `<2 x double>`, `<4 x i64>`, …; functions take and return
  them in registers. Lane operations are vector instructions, plus the `llvm.fma`/`llvm.sqrt`
  vector intrinsics.
  `--release` builds for the host CPU (`-march=native`) so these use the machine's full vector
  width and its FMA unit; without that, a vector `fma` would be one libm call per lane. Set
  `AXION_MARCH` (any clang `-march`, e.g. `AXION_MARCH=x86-64`) to build a binary for other
  machines. Results do not change: the IR has no fast-math flags, so nothing is fused or
  reordered either way.
- **`--dev` (Cranelift).** Each vector is its lanes: one variable per lane, one parameter per
  lane, and a multi-value return.

Fixtures: `tests/fixtures/simd.axi`, `simd_oob.axi`, `simd_reject.axi`. Benchmark: `bench/simd_dot`.
