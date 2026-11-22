# GPU kernels

`gpuFor` runs a loop over an array on the GPU:

```haskell
gpuFor :: Array a -> (Int -> a -> a) -> Array a
```

It means exactly what [`parFor`](parallel.md) means: element `i` of the array becomes `k i a[i]`.
Only where it runs differs. Under `--release` the kernel is compiled for the GPU and runs there,
one GPU thread per element. Everywhere else (the interpreter, `--dev`, a machine without a GPU)
it runs like `parFor`. The output is the same, bit for bit, wherever it runs.

```haskell
-- a matrix (row-major, n × n) times a vector, one row per GPU thread
dotRow :: Array Float -> Array Float -> Int -> Int -> Int -> Float -> Float
dotRow m v n r j acc =
  if j >= n then acc else dotRow m v n r (j + 1) (acc +. getArray m (r * n + j) *. getArray v j)

matVec :: Array Float -> Array Float -> Int -> Array Float
matVec m v n = gpuFor (newArray n 0.0) (\r _ -> dotRow m v n r 0 0.0)
```

## What a kernel can do

A GPU kernel computes with `Int`, `Float` and `Bool` values:
- arithmetic, comparisons, `if`, `case` on numbers, and `let`;
- `getArray` and `lenArray` on the arrays it captures (here `m` and `v`), and the values it
  captures;
- `toFloat`, `truncate`, `sqrt`, `floor`, `abs`, `div` and `mod`;
- calls to functions that do the same, including recursive ones (a loop is a tail call).

It cannot use strings, lists, tuples, records or other `data` values, or function values. A
kernel that does is **AX0802**, naming the first such use and the functions on the way to it:

```
error[AX0802]: a `gpuFor` kernel must run on the GPU: it uses `strLen`, which cannot run on the GPU, in `label`
```

Use `parFor` for such a kernel. The rules of every parallel kernel also apply: no effects
(**AX0800**), and the call written out with both arguments (**AX0801**). The check reads the
source; a native build checks the compiled kernel again (also AX0802), and so also catches what
overloading hides, such as `==` on a `data` type.

Contracts and refinements work as everywhere else. Inside the kernel, `0 <= i < len a` is known
for the array the loop runs over, so most accesses at `i` are proven. A contract that stays a
run-time check runs on the GPU as well (see below for what happens when it fails).

## Same results

- **Floating point.** The GPU computes IEEE double precision, as the CPU does: each `+. -. *.
  /.` and `sqrt` is correctly rounded, and no multiply-add is fused (`-nvptx-fma-level=0`). So
  `showFloat` prints the same digits.
- **Integers.** `Int` is 64-bit on the GPU too, with the same wrapping arithmetic.
- **A failure.** An index out of range, a division by zero or a contract violation makes the GPU
  kernel trap. The array is left as it was and the loop runs again on the CPU, which stops the
  program with the CPU's own message (`axion: array bounds — index 100 out of range [0, 100)`).
  Every backend fails the same way.

## How it runs

- **Compiling.** `--release` compiles each kernel's function, and everything it calls, a second
  time for the GPU: the same LLVM IR, targeted at `nvptx64` (clang, no CUDA toolkit), giving PTX
  that the binary carries. A clang without the NVPTX target leaves the kernels on the CPU, with a
  warning.
- **Running.** The runtime loads the NVIDIA driver (`libcuda`) when the first `gpuFor` runs. It
  needs nothing installed beyond the driver. It copies the array and the arrays the kernel
  captures to the GPU, starts one thread per element, and copies the array back.
- **Without a GPU** (no driver, no device, an error), the loop runs on the CPU.
- **Controls.** `AXION_GPU=off` forces the CPU. `AXION_GPU=report` says once where the loops run
  (`axion: gpuFor runs on the GPU (NVIDIA GeForce GTX 1650)`). Also: `AXION_GPU_ARCH` (the PTX
  target, default `sm_52`) and `AXION_CUDA_LIB` (the driver library's path).
- **Nesting.** A `gpuFor` inside a `parFor` kernel runs on the CPU.

## Speed

Consumer GPUs are fast at 32-bit arithmetic and slow at 64-bit. On a GTX 1650, double precision
runs at 1/32 of single precision, and 64-bit integer operations are emulated. So write a GPU
kernel in [`Float32` and `Int32`](numbers32.md) where 32 bits are enough. A Mandelbrot frame
(1024², up to 500 iterations a pixel) on that GPU:

| | time per frame |
|---|---|
| `parFor`, 8 CPU threads, `Float` or `Float32` | about 51 ms |
| `gpuFor`, `Float` | about 29 ms |
| `gpuFor`, `Float32` | about 12 ms |

Starting the GPU (driver initialization and the PTX compile) costs about 165 ms once per run.

Fixtures: `tests/fixtures/gpu.axi`, `gpu_reject.axi`. Fuzzing: `scripts/fuzz.py --only gpu`
(random integer and float kernels: every backend prints the same bits and fails the same way).
