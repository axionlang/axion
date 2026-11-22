# 32-bit numbers

`Int32` and `Float32` are 32-bit versions of `Int` and `Float`:

| Type | Values | Arithmetic |
|---|---|---|
| `Int32` | -2147483648 … 2147483647 | wraps at 32 bits, like `Int` at 64 |
| `Float32` | IEEE single precision | each operation rounded once to a single |

They are for code that needs exactly 32-bit behavior: integer arithmetic that wraps at 32 bits
(hashes, random number generators, formats defined in 32 bits) and single-precision results that
match other single-precision code. On the CPU they run at about the speed of `Int` and `Float`.
Each still takes a 64-bit slot (see below), so they save no memory yet.

```haskell
harmonic :: Float32 -> Int32 -> Float32
harmonic acc n = if n <= 0 then acc else harmonic (acc + 1.0 / int32ToFloat32 n) (n - 1)
```

## Operators and literals

The usual operators work on them: `+ - *`, `/` (`div` for `Int32`), `div` and `mod` (`Int32`),
`== /= < <= > >=`, and `show`. An `Int32` `div` truncates and `mod` takes the sign of the
dividend, as for `Int`. Dividing by zero stops the program, and `minBound / -1` wraps.

A literal takes the type the context expects: `x + 1` with `x :: Int32` adds an `Int32` one, and
`acc + 1.0` with `acc :: Float32` a `Float32` one (rounded to the nearest single). An integer
literal that does not fit in 32 bits is an error. As with `Float`, a `Float32` literal is written
with a point (`1.0`, not `1`).

The types never mix silently: `Int32` + `Int` is a type error. Convert explicitly:

| Function | Type | |
|---|---|---|
| `toInt32` | `Int -> Int32` | the low 32 bits (wraps) |
| `fromInt32` | `Int32 -> Int` | exact |
| `toFloat32` | `Float -> Float32` | rounded to the nearest single |
| `fromFloat32` | `Float32 -> Float` | exact |
| `int32ToFloat32` | `Int32 -> Float32` | rounded to the nearest single |
| `truncateF32` | `Float32 -> Int32` | toward zero; saturating (NaN is 0) |
| `sqrtF32` | `Float32 -> Float32` | correctly rounded |
| `showFloat32` | `Float32 -> String` | the shortest decimal that reads back as the same single (`0.1`) |

`show` on a `Float32` is `showFloat32`. `fromFloat32 0.1` is `0.10000000149011612`: the single
nearest to 0.1, shown as a double.

## Same bits everywhere

Every backend computes the same results: the interpreter, `--dev` and `--release`.
`axionc/src/num32.rs` holds the reference semantics, and the native backends emit 32-bit
instructions with the same rounding. No multiply-add is fused.

## Representation

Like every value, a 32-bit number occupies a 64-bit slot. An `Int32` is kept sign-extended, so
comparisons and `case` on literals are the `Int` ones. A `Float32` keeps its bits in the low
half. So an `Array Float32` still takes 8 bytes per element; packed 4-byte arrays would be a
further step.

Fixtures: `tests/fixtures/numbers32.axi`, `numbers32_reject.axi`.
